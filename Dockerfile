FROM openjdk:17
EXPOSE 8080
WORKDIR /app
COPY /target/*.jar app.jar
RUN chmod +755 -R /app
CMD ["java", "-jar", "/app/app.jar"]
