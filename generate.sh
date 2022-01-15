#!/bin/sh

GENERATED="./gPhone/Model/generated"

mkdir -p $GENERATED
protoc main.proto --swift_out=$GENERATED --grpc-swift_opt=Client=true,Server=false --grpc-swift_out=$GENERATED
