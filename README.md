# Figures
This is a sinatra microservice for running PDFFigures2 fat jar. It will extract the images and returns JSON with the URIs of the extracted images.

The API provides three main functions:
1. `/process` to extract figures from a given PDF URL
2. an image server for the assets
3. `/cleanup` to remove the assets

### Developing

`RACK_ENV=development be rackup -p 4567` starts the server.

### Steps to use this

1. Build the docker image
`docker build -t figures .`

and tag it:
`docker image tag figures dluan/figures:0.0.5`

2. Run the image to start the sinatra web host
`docker run -p 4567:4567 dluan/figures:0.0.5`

Or if running on an external instance, forward 80.
`docker run -t --init --rm -p 80:4567 dluan/figures:0.0.5`

3. Once it's running you can post to it like so:
```
curl localhost:4567/process -X POST -H "Content-Type: application/json" -d '{"pdf": "https://storage.googleapis.com/jellyposter-store/d5058c6990e36d68068ad98422372b6b.pdf", "upload_id": "1"}'
```

### Deploying
This can be deployed on Heroku or GCE. It is also avilable as an image on docker hub: https://hub.docker.com/repository/docker/dluan/figures.