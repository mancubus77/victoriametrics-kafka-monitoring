.PHONY = build-cluster destroy run-oc-producer get-certs get-hostname destroy env
.SILENT: get-hostname
# .EXPORT_ALL_VARIABLES:
# HOSTNAME = HOSTNAME

SHELL := /bin/bash
BROKER ?= my-cluster-kafka-bootstrap-kafka.apps.ocp4.rhpg.org:443
GROUP ?= group
TOPIC ?= my-topic
STOREPASS ?= password
build-cluster:
		oc apply -k .

destroy:
		oc delete -k .

run-oc-producer: 
		oc run kafka-producer -ti --image=registry.access.redhat.com/amq7/amq-streams-kafka:1.1.0-kafka-2.1.1 --rm --restart=Never -- bin/kafka-console-producer.sh --broker-list my-cluster-kafka-bootstrap:9092 --topic ${TOPIC}

get-certs: get-hostname
		oc extract secret/my-cluster-clients-ca-cert -n kafka --keys=ca.crt --to=- > ca.crt
		oc extract secret/my-cluster-clients-ca -n kafka --keys=ca.key --to=- > server.key.pem 
		rm -rf truststore.jks 2>/dev/null
		keytool -import -trustcacerts -alias root -file ca.crt -keystore truststore.jks -storepass ${STOREPASS} -noprompt
		keytool -importkeystore -srckeystore truststore.jks -destkeystore server.p12 -deststoretype PKCS12 -srcstorepass ${STOREPASS} -deststorepass ${STOREPASS} -noprompt
		openssl pkcs12 -in server.p12 -nokeys -out server.cer.pem -passin 'pass:${STOREPASS}'
		rm ca.crt ca.key server.p12 truststore.jks 2>/dev/null; true

run-consumer: 
		source .env && go run cmd/go-amq-kafka-consumer/consumer.go $${BROKER} ${GROUP} ${TOPIC} 2>/dev/null; true

run-producer:
		source .env && go run cmd/go-amq-kafka-consumer/producer.go $${BROKER} ${TOPIC} 2>/dev/null; true

run-producer-generator:
		source .env && go run cmd/go-amq-kafka-consumer/producer.go $${BROKER} ${TOPIC} 1000 2>/dev/null; true

get-hostname: 
		$(eval HOSTNAME := $(shell oc get routes my-cluster-kafka-bootstrap -o=jsonpath='{.status.ingress[0].host}{"\n"}')) > /dev/null
		echo BROKER=$(HOSTNAME):443 > .env