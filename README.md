# BigIz
## This is a sinatra microservice for running PDFFigures2 fat jar

This microservice uses sinatra on jruby to process a given pdf. It will extract the images and push them to Google Cloud Storage, and returns JSON with the URIs of the extracted images.

## Steps to use this

1. Build the docker image
`docker build -t sinatra-demo .`

2. Run the image to start the sinatra web host
`docker run -p 80:4567 sinatra-demo`

Once it's running you can post to it like so:
```
curl localhost:4567/process -X POST -H "Content-Type: application/json" -d '{"pdf": "https://storage.googleapis.com/jellyposter-store/d5058c6990e36d68068ad98422372b6b.pdf", "upload_id": "1"}'
```
