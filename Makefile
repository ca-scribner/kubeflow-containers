# Dockerfile Builder
# ==================
#
# All the content is in `docker-bits`; this Makefile
# just builds target dockerfiles by combining the dockerbits.

# The docker-stacks tag
DOCKER-STACKS-UPSTREAM-TAG := r-4.0.3

Tensorflow-CUDA := 11.1
PyTorch-CUDA    := 11.0

# https://stackoverflow.com/questions/5917413/concatenate-multiple-files-but-include-filename-as-section-headers
CAT := awk '(FNR==1){print "\n\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\n\#\#\#  " FILENAME "\n\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\n"}1'
SRC := docker-bits
RESOURCES := resources
OUT := output
TMP := .tmp
OL := OL-compliant
DEFAULT_REPO := k8scc01covidacr.azurecr.io
PYTHON_VENV := .venv
PYTHON := $(PYTHON_VENV)/bin/python
TESTS_DIR := ./tests

DEFAULT_PORT := 8888



.PHONY: clean .output all

clean:
	rm -rf $(OUT) $(TMP)

.output:
	mkdir -p $(OUT)/ $(TMP)/

all: JupyterLab RStudio RemoteDesktop docker-stacks-datascience-notebook
	@echo "All dockerfiles created."

build:
	for d in output/*; do \
		tag=$$(basename $$d | tr '[:upper:]' '[:lower:]'); \
		echo $$tag; \
		cd $$d; \
		docker build . -t kubeflow-$$tag; \
		cd ../../; \
	done;

#############################
###    Generated Files    ###
#############################
get-docker-stacks-upstream-tag:
	@echo $(DOCKER-STACKS-UPSTREAM-TAG)

generate-CUDA:
	bash scripts/get-nvidia-stuff.sh $(TensorFlow-CUDA) > $(SRC)/1_CUDA-$(TensorFlow-CUDA).Dockerfile
	bash scripts/get-nvidia-stuff.sh    $(PyTorch-CUDA) > $(SRC)/1_CUDA-$(PyTorch-CUDA).Dockerfile

generate-Spark:
	bash scripts/get-spark-stuff.sh --commit $(COMMIT)  > $(SRC)/2_Spark.Dockerfile

#############################
###   Bases GPU & Spark   ###
#############################

# Configure the "Bases".
#
PyTorch Tensorflow: .output
	$(CAT) \
		$(SRC)/0_CPU.Dockerfile \
		$(SRC)/1_CUDA-$($(@)-CUDA).Dockerfile \
		$(SRC)/2_$@.Dockerfile \
	> $(TMP)/$@.Dockerfile

CPU: .output
	$(CAT) $(SRC)/0_$@.Dockerfile > $(TMP)/$@.Dockerfile

################################
###    R-Studio & Jupyter    ###
################################

# Only one output version
RStudio: CPU
	mkdir -p $(OUT)/$@
	cp -r resources/common/* $(OUT)/$@

	$(CAT) \
		$(TMP)/$<.Dockerfile \
		$(SRC)/3_Kubeflow.Dockerfile \
		$(SRC)/4_CLI.Dockerfile \
		$(SRC)/5_DB-Drivers.Dockerfile \
		$(SRC)/6_$(@).Dockerfile \
		$(SRC)/∞_CMD.Dockerfile \
	>   $(OUT)/$@/Dockerfile

# create directories for current images and OL-compliant images
# create OL images with OL-compliant docker-bits, temporary until we want to replace our JupyterLab images with the OL compliant ones
JupyterLab: PyTorch Tensorflow CPU 
	
	for type in $^; do \
		mkdir -p $(OUT)/$@-$${type}; \
		cp -r resources/common/* $(OUT)/$@-$${type}/; \
		$(CAT) \
			$(TMP)/$${type}.Dockerfile \
			$(SRC)/3_Kubeflow.Dockerfile \
			$(SRC)/4_CLI.Dockerfile \
			$(SRC)/5_DB-Drivers.Dockerfile \
			$(SRC)/6_$(@).Dockerfile \
			$(SRC)/∞_CMD.Dockerfile \
		>   $(OUT)/$@-$${type}/Dockerfile; \
		mkdir -p $(OUT)/$@-$${type}-$(OL); \
		cp -r resources/common/* $(OUT)/$@-$${type}-$(OL)/; \
		$(CAT) \
			$(TMP)/$${type}.Dockerfile \
			$(SRC)/3_Kubeflow.Dockerfile \
			$(SRC)/4_CLI.Dockerfile \
			$(SRC)/5_DB-Drivers.Dockerfile \
			$(SRC)/6_$(@)-$(OL).Dockerfile \
			$(SRC)/∞_CMD.Dockerfile \
		>   $(OUT)/$@-$${type}-$(OL)/Dockerfile; \
	done

# Remote Desktop
RemoteDesktop:
	mkdir -p $(OUT)/$@
	echo "REMOTE DESKTOP"
	cp -r scripts/remote-desktop $(OUT)/$@
	cp -r resources/common/* $(OUT)/$@
	cp -r resources/remote-desktop/* $(OUT)/$@

	$(CAT) \
		$(SRC)/0_Rocker.Dockerfile \
		$(SRC)/3_Kubeflow.Dockerfile \
		$(SRC)/4_CLI.Dockerfile \
		$(SRC)/6_RemoteDesktop.Dockerfile \
		$(SRC)/∞_CMD_RemoteDesktop.Dockerfile \
	>   $(OUT)/$@/Dockerfile

# Debugging Dockerfile build that essentially uses docker-stacks images
# Used for when you need something to build quickly during debugging
docker-stacks-datascience-notebook:
	mkdir -p $(OUT)/$@
	cp -r resources/common/* $(OUT)/$@

	DS_TAG=$$(make -s get-docker-stacks-upstream-tag); \
	echo "DS_TAG = $${DS_TAG}"; \
	echo "ARG BASE_VERSION=$${DS_TAG}" > $(OUT)/$@/Dockerfile; \
	echo "FROM jupyter/datascience-notebook:\$$BASE_VERSION" >> $(OUT)/$@/Dockerfile
	echo "CMD [\"sh\"]" >> $(OUT)/$@/Dockerfile

# 	cat $(OUT)/$@/Dockerfile $(SRC)/∞_CMD.Dockerfile > $(OUT)/$@/Dockerfile

check-python-venv:
	@if $(PYTHON) --version> /dev/null 2>&1; then \
		echo "Found dev python venv via $(PYTHON)"; \
	else \
		echo -n 'No dev python venv found at $(PYTHON)\n' \
				'Please run `make install-python-dev-venv` to build a dev python venv'; \
		exit 1; \
	fi

check-port-available:
	@if curl http://localhost:$(DEFAULT_PORT) > /dev/null 2>&1; then \
		echo "Port $(DEFAULT_PORT) busy - clear port or change default before continuing"; \
		exit 1; \
	fi

check-test-prereqs: check-python-venv check-port-available

install-python-dev-venv:
	python3 -m venv $(PYTHON_VENV)
	$(PYTHON) -m pip install -Ur requirements-dev.txt

test/%: REPO?=$(DEFAULT_REPO)
test/%: check-test-prereqs # Run all generic and image-specific tests against an image
	# End repo with exactly one trailing slash, unless it is empty
	echo "(before) REPO = $$REPO" ;\
	REPO=$$(echo "$$REPO" | sed 's:/*$$:/:' | sed 's:^\s*/*\s*$$::') ;\
	echo "(after) REPO = $$REPO" ;\
	TESTS="$(TESTS_DIR)/general";\
	SPECIFIC_TEST_DIR="$(TESTS_DIR)/$(notdir $@)";\
	if [ ! -d "$${SPECIFIC_TEST_DIR}" ]; then\
		echo "No specific tests found for $${SPECIFIC_TEST_DIR}.  Running only general tests";\
	else\
		TESTS="$${TESTS} $${SPECIFIC_TEST_DIR}";\
		echo "Found specific tests folder";\
	fi;\
	echo "Running tests on folders '$${TESTS}'";\
	IMAGE_NAME="$${REPO}$(notdir $@)" $(PYTHON) -m pytest -m "not info" $${TESTS}
