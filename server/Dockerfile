FROM google/dart:2.12-dev

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
COPY --from=0 /app/bin/server /app/bin/server
COPY --from=0 /app/public /app/public
EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
