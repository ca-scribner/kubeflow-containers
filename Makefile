# Dockerfile Builder
# ==================
#
# All the content is in `docker-bits`; this Makefile
# just builds target dockerfiles by combining the dockerbits.

# The docker-stacks tag
COMMIT := 42f4c82a07ff

Tensorflow-CUDA := 11.1
PyTorch-CUDA    := 11.0

# https://stackoverflow.com/questions/5917413/concatenate-multiple-files-but-include-filename-as-section-headers
CAT := awk '(FNR==1){print "\n\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\n\#\#\#  " FILENAME "\n\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\n"}1'
SRC := docker-bits
RESOURCES := resources
OUT := output
TMP := .tmp
OL := OL-compliant

.PHONY: clean .output all

clean:
	rm -rf $(OUT) $(TMP)

.output:
	mkdir -p $(OUT)/ $(TMP)/

# I think i need to add "RemoteDesktop" here
all: JupyterLab RStudio RemoteDesktop
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
get-commit:
	@echo $(COMMIT)

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
	cp -r resources/* $(OUT)/$@

	$(CAT) \
		$(TMP)/$<.Dockerfile \
		$(SRC)/3_Kubeflow.Dockerfile \
		$(SRC)/4_CLI.Dockerfile \
		$(SRC)/5_DB-Drivers.Dockerfile \
		$(SRC)/6_$(@).Dockerfile \
		$(SRC)/∞_CMD.Dockerfile \
	>   $(OUT)/$@/Dockerfile

# create directories for current images and OL-compliant JupyterLab3 images
JupyterLab: PyTorch Tensorflow CPU 
	
	for type in $^; do \
		mkdir -p $(OUT)/$@-$${type}; \
		cp -r resources/* $(OUT)/$@-$${type}/; \
		$(CAT) \
			$(TMP)/$${type}.Dockerfile \
			$(SRC)/3_Kubeflow.Dockerfile \
			$(SRC)/4_CLI.Dockerfile \
			$(SRC)/5_DB-Drivers.Dockerfile \
			$(SRC)/6_$(@).Dockerfile \
			$(SRC)/∞_CMD.Dockerfile \
		>   $(OUT)/$@-$${type}/Dockerfile; \
		mkdir -p $(OUT)/$@-$${type}-$(OL); \
		cp -r resources/* $(OUT)/$@-$${type}-$(OL)/; \
		$(CAT) \
			$(TMP)/$${type}.Dockerfile \
			$(SRC)/3_Kubeflow.Dockerfile \
			$(SRC)/4_CLI.Dockerfile \
			$(SRC)/5_DB-Drivers.Dockerfile \
			$(SRC)/6_$(@)-$(OL).Dockerfile \
			$(SRC)/∞_CMD.Dockerfile \
		>   $(OUT)/$@-$${type}-$(OL)/Dockerfile; \
	done	

# Remote Desktop, this file does not get generated. 
#For some reason the SRC/7 is not getting detected. 
#no it dies at COPY helpers.sh, the last line in the 4_CLI.Dockerfile
RemoteDesktop: CPU
	mkdir -p $(OUT)/$@
	echo "REMOTE DESKTOP" 
	cp -r resources/* $(OUT)/$@

	$(CAT) \
		$(TMP)/$<.Dockerfile \
		$(SRC)/7_RemoteDesktop.Dockerfile \
	>   $(OUT)/$@/Dockerfile
