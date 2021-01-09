# Chat Server

1. Re-generates bin/server.dart from lib/functions.dart

   `dart run build_runner build`


2. Generate flutter client and put web result in `public` directory.

   __public__ directory is generated code.

   See `client` folder `README.md`


3. Create docker container image.

   `docker build -t chat-server .`


4. Run and test locally.

   `docker run -it -p 8080:8080 --rm --name app chat-server`

   Visit your docker machine web address, and you should see the chat client working.


5. Deploy to Google Cloud Run

   1. `gcloud config set core/project <PROJECT-ID>`

   2. `gcloud config set run/platform managed`

   3. `gcloud config set run/region <REGION>`

       For a list of regions, run `gcloud compute regions list`.

   5. This command deploys to google cloud as source and compiles on their build server.

      `gcloud beta run deploy chat-server --source=. --allow-unauthenticated`

      Or, push your own local docker image to Google Container Registry.
      [Reference](https://cloud.google.com/container-registry/docs/pushing-and-pulling)

      `docker tag chat-server gcr.io/<PROJECT-ID>/chat-server`

      `docker push gcr.io/<PROJECT-ID>/chat-server`

      Then deploy that image:

      `gcloud beta run deploy chat-server --image=gcr.io/<PROJECT-ID>/chat-server --allow-unauthenticated`
