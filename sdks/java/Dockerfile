FROM openjdk:11

WORKDIR /usr/src/app

COPY rts-client . 

RUN javac src/com/atomicobject/rts/*.java -d bin/  -cp lib/json-simple-1.1.1.jar

WORKDIR /usr/src/app/bin

EXPOSE 9090
ENTRYPOINT ["java", "-cp", "./:../lib/json-simple-1.1.1.jar","com.atomicobject.rts.Main", "9090"]
