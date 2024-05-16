# ca-trust

This directory is used by the Docker build process as an interface to pass trusted CA certs into a container image.

<<<<<<< HEAD

On the master branch, this file is included in git, but the rest of the contents of this directory are gitignore'd.

On the k8s branch, the forward proxy certificate is included so it can be injected into the k8s image during build time.

=======
This file is included in git, but the rest of the contents of this directory are gitignore'd.

The forward proxy certificate is included so it can be injected into the k8s image during build time.
>>>>>>> master
