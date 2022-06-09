
all:	jupyterhub_debian.sif

jupyterhub_debian.sif: jupyterhub_debian.tar 
	singularity build jupyterhub_debian.sif docker-archive://jupyterhub_debian.tar

jupyterhub_debian.tar: Dockerfile jupyterhub_config.py
	docker build -t jupyterhub-debian .
	docker save jupyterhub-debian:latest -o jupyterhub_debian.tar

clean:
	rm -f jupyterhub_debian.tar
	rm -f jupyterhub_debian.sif

