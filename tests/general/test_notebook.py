# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
import logging

LOGGER = logging.getLogger(__name__)

def test_server_alive(container, http_client, url="http://localhost:8888"):
    """Notebook server should eventually appear with a recognizable page."""
    LOGGER.info("Running test_server_alive")
    LOGGER.info("launching the container")
    container.run()
    LOGGER.info(f"accessing {url}")
    resp = http_client.get(url)
    resp.raise_for_status()
    LOGGER.debug(f"got text from url: {resp.text}")

    # Not sure why but some flavors of JupyterLab don't hit the first one
    try:
        assert "<title>JupyterLab" in resp.text, \
            "Image does not appear to start to JupyterLab page.  Try starting yourself and browsing to it to see what is happening"
    except AssertionError as e:
        assert '<span id="running_list_info">Currently running Jupyter processes</span>' in resp.text, e
