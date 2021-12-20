This docker image is used so that all developers do not need to set up a python
environment or install jinja.  Since the image changes so rarely, we didn't set up
a build pipeline in Travis, it is just built manually with the command

```shell
TAG=rmelickvida/jinja2-cli:$(git rev-parse --short HEAD)
docker build -t ${TAG} .
docker push ${TAG}
```

After building a new image, the `environment-update.sh` script should be updated
