FROM google/dart:2.12-dev AS dart

RUN apt update && apt install busybox

WORKDIR /app
COPY pubspec.yaml /app/pubspec.yaml
RUN dart pub get
COPY . .
RUN dart pub get --offline

RUN dart pub run build_runner build --delete-conflicting-outputs
RUN dart --no-sound-null-safety tools/compile.dart bin/server.dart

########################

FROM subfuzion/dart:slim
WORKDIR /app
COPY --from=dart /app/bin/server /app/bin/server
COPY --from=dart /app/public /app/public

COPY --from=dart /usr/bin/busybox /bin/busybox
COPY --from=dart /usr/bin/busybox /bin/sh
RUN /bin/busybox --install -s /bin

EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
