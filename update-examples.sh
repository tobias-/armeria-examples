#!/bin/bash -e
ASSERTJ_VERSION='3.23.1'
AWAITILITY_VERSION='4.2.0'
DAGGER_VERSION='2.44.2'
DEPENDENCY_MANAGEMENT_PLUGIN_VERSION='1.0.11.RELEASE'
DROPWIZARD_VERSION='2.1.4'
IO_PROJECTREACTOR_VERSION='3.4.26'
JSON_UNIT_VERSION='2.36.0'
JSR305_VERSION='3.0.2'
JUNIT_VERSION='4.13.2'
JUNIT_PLATFORM_VERSION='5.9.1'
MICROMETER_VERSION='1.10.2'
NETTY_VERSION='4.1.86.Final'
ORG_JRUYI_THRIFT="0.4.2"
PROMETHEUS_VERSION='0.16.0'
PROTOC_VERSION='3.21.1'
PROTOC_GEN_GRPC_VERSION='1.48.0'
REACTIVE_GRPC_VERSION='1.2.3'
RESILIENCE4J2_VERSION='2.0.2'
SLF4J_VERSION='1.7.36'
SPRING_BOOT_VERSION='2.7.4'
SPOTIFY_COMPLETABLE_FUTURES_VERSION='0.3.5'
SPOTIFY_FUTURES_EXTRA_VERSION='4.3.1'
JAVAX_ANNOTATION_VERSION='1.3.2'
HIBERNATE_VERSION='6.2.3.Final'

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <Armeria version> <Armeria working copy path>"
  exit 1
fi

READLINK_PATH="$(which greadlink 2>/dev/null || true)"
if [[ -z "$READLINK_PATH" ]]; then
  READLINK_PATH="$(which readlink 2>/dev/null || true)"
fi
if [[ -z "$READLINK_PATH" ]]; then
  echo "Cannot find 'readlink'"
  exit 1
fi

VERSION="$1"
SRC_DIR="$($READLINK_PATH -f "$2")"

if [[ ! -d "$SRC_DIR/.git" ]]; then
  echo "Not a git repository: $SRC_DIR"
  exit 1
fi
cd "$(dirname "$0")"

echo 'Copying README.md ..'
cp -f "$SRC_DIR/examples/README.md" .

function find_examples() {
  find "$SRC_DIR/examples" -mindepth 1 -maxdepth 2 -type d -print | while read -r D; do
    if [[ -f "$D/build.gradle" && "$D" != *-scala && "$D" != *-sangria ]]; then
      echo "${D##*/examples/}"
    fi
  done
}

echo 'Copying examples ..'
for E in $(find_examples); do
  rsync --archive --delete "$SRC_DIR/examples/$E/" "$E"
done

echo 'Copying Gradle wrapper ..'
for E in $(find_examples); do
  cp "$SRC_DIR/gradlew" "$SRC_DIR/gradlew.bat" "$E"
  mkdir "$E/gradle"
  cp -r "$SRC_DIR/gradle/wrapper" "$E/gradle"
done

for E in $(find_examples); do
  echo "Patching $E/build.gradle .."
  TMPF="$(mktemp)"

  # Start with removing the 'buildscript' section.
  perl -e '
    undef $/; $_=<>;
    s/(^|\n|\s)*buildscript \{(\n|.)*?\n}//;
    print
  ' < "$E/build.gradle" > "$TMPF"

  # Remove the 'apply plugin' statements.
  perl -i -pe 's/^apply plugin:.*$//g' "$TMPF"

  # Replace the 'project(...)' dependencies.
  perl -i \
    -pe "s/project\\(':core'\\)/'com.linecorp.armeria:armeria'/g;" \
    -pe "s/project\\(':dropwizard2'\\)/'com.linecorp.armeria:armeria-dropwizard2'/g;" \
    -pe "s/project\\(':graphql'\\)/'com.linecorp.armeria:armeria-graphql'/g;" \
    -pe "s/project\\(':graphql-protocol'\\)/'com.linecorp.armeria:armeria-graphql-protocol'/g;" \
    -pe "s/project\\(':grpc'\\)/'com.linecorp.armeria:armeria-grpc'/g;" \
    -pe "s/project\\(':junit5'\\)/'com.linecorp.armeria:armeria-junit5'/g;" \
    -pe "s/project\\(':logback'\\)/'com.linecorp.armeria:armeria-logback'/g;" \
    -pe "s/project\\(':reactor3'\\)/'com.linecorp.armeria:armeria-reactor3'/g;" \
    -pe "s/project\\(':resilience4j2'\\)/'com.linecorp.armeria:armeria-resilience4j2'/g;" \
    -pe "s/project\\(':rxjava3'\\)/'com.linecorp.armeria:armeria-rxjava3'/g;" \
    -pe "s/project\\(':saml'\\)/'com.linecorp.armeria:armeria-saml'/g;" \
    -pe "s/project\\(':spring:boot2-actuator-starter'\\)/'com.linecorp.armeria:armeria-spring-boot2-actuator-starter'/g;" \
    -pe "s/project\\(':spring:boot2-autoconfigure'\\)/'com.linecorp.armeria:armeria-spring-boot2-autoconfigure'/g;" \
    -pe "s/project\\(':spring:boot2-starter'\\)/'com.linecorp.armeria:armeria-spring-boot2-starter'/g;" \
    -pe "s/project\\(':spring:boot2-webflux-autoconfigure'\\)/'com.linecorp.armeria:armeria-spring-boot2-webflux-autoconfigure'/g;" \
    -pe "s/project\\(':spring:boot2-webflux-starter'\\)/'com.linecorp.armeria:armeria-spring-boot2-webflux-starter'/g;" \
    -pe "s/project\\(':tomcat9'\\)/'com.linecorp.armeria:armeria-tomcat9'/g;" \
    -pe "s/project\\(':thrift0.17'\\)/'com.linecorp.armeria:armeria-thrift0.17'/g;" \
    "$TMPF"

  # Remove the line that refers to `project(':annotation-processor')`.
  perl -i -pe 's/^.*:annotation-processor.*$//g' "$TMPF"

  # Append version numbers to the 3rd party dependencies.
  perl -i \
    -pe "s/libs.protobuf.java.util/'com.google.protobuf:protobuf-java-util:$PROTOC_VERSION'/g;" \
    -pe "s/libs.dagger.producers/'com.google.dagger:dagger-producers:$DAGGER_VERSION'/g;" \
    -pe "s/libs.dagger.compiler/'com.google.dagger:dagger-compiler:$DAGGER_VERSION'/g;" \
    -pe "s/libs.dagger/'com.google.dagger:dagger:$DAGGER_VERSION'/g;" \
    -pe "s/libs.reactor.grpc.stub/'com.salesforce.servicelibs:reactor-grpc-stub:$REACTIVE_GRPC_VERSION'/g;" \
    -pe "s/libs.futures.completable/'com.spotify:completable-futures:$SPOTIFY_COMPLETABLE_FUTURES_VERSION'/g;" \
    -pe "s/libs.futures.extra/'com.spotify:futures-extra:$SPOTIFY_FUTURES_EXTRA_VERSION'/g;" \
    -pe "s/libs.dropwizard2.testing/'io.dropwizard:dropwizard-testing:$DROPWIZARD_VERSION'/g;" \
    -pe "s/libs.reactor.core/'io.projectreactor:reactor-core:$IO_PROJECTREACTOR_VERSION'/g;" \
    -pe "s/libs.reactor.test/'io.projectreactor:reactor-test:$IO_PROJECTREACTOR_VERSION'/g;" \
    -pe "s/libs.micrometer.prometheus/'io.micrometer:micrometer-registry-prometheus'/g;" \
    -pe "s/libs.prometheus/'io.prometheus:simpleclient_common:$PROMETHEUS_VERSION'/g;" \
    -pe "s/libs.resilience4j.springboot2/'io.github.resilience4j:resilience4j-spring-boot2'/g;" \
    -pe "s/libs.resilience4j.micrometer/'io.github.resilience4j:resilience4j-micrometer'/g;" \
    -pe "s/libs.javax.annotation/'javax.annotation:javax.annotation-api:$JAVAX_ANNOTATION_VERSION'/g;" \
    -pe "s/libs.junit4/'junit:junit:$JUNIT_VERSION'/g;" \
    -pe "s/libs.junit5.jupiter.api/'org.junit.jupiter:junit-jupiter-api'/g;" \
    -pe "s/libs.json.unit.fluent/'net.javacrumbs.json-unit:json-unit-fluent:$JSON_UNIT_VERSION'/g;" \
    -pe "s/libs.assertj/'org.assertj:assertj-core:$ASSERTJ_VERSION'/g;" \
    -pe "s/libs.awaitility/'org.awaitility:awaitility:$AWAITILITY_VERSION'/g;" \
    -pe "s/libs.slf4j.simple/'org.slf4j:slf4j-simple:$SLF4J_VERSION'/g;" \
    -pe "s/libs.spring.boot2.configuration.processor/'org.springframework.boot:spring-boot-configuration-processor:$SPRING_BOOT_VERSION'/g;" \
    -pe "s/libs.spring.boot2.starter.test/'org.springframework.boot:spring-boot-starter-test:$SPRING_BOOT_VERSION'/g;" \
    -pe "s/libs.spring.boot2.starter.web/'org.springframework.boot:spring-boot-starter-web:$SPRING_BOOT_VERSION'/g;" \
    -pe "s/libs.hibernate.validator/'org.hibernate.validator:hibernate-validator:$HIBERNATE_VERSION'/g;" \
    "$TMPF"

  {
    if [[ "$E" == *grpc* ]]; then
      echo 'buildscript {'
      echo '    dependencies {'
      echo "        classpath 'com.google.protobuf:protobuf-gradle-plugin:0.8.12'"
      echo '    }'
      echo '}'
    fi
    # Add the 'plugins' section.
    PLUGINS=('io.spring.dependency-management')
    PLUGIN_VERSIONS=("$DEPENDENCY_MANAGEMENT_PLUGIN_VERSION")
    if grep -qF spring-boot "$TMPF"; then
      PLUGINS+=('org.springframework.boot')
      PLUGIN_VERSIONS+=("$SPRING_BOOT_VERSION")
    fi
    echo 'plugins {'
    if grep -qF "id 'application'" "$TMPF"; then
      echo "    id 'application'"
    fi

    if [[ "$E" == thrift* ]]; then
      echo "    id \"org.jruyi.thrift\" version \"${ORG_JRUYI_THRIFT}\""
    fi

    for ((I=0; I<${#PLUGINS[@]}; I++)); do
      echo "    id \"${PLUGINS[$I]}\" version \"${PLUGIN_VERSIONS[$I]}\""
    done
    echo '}'
    echo

    # Remove the application plugin because we added it.
    perl -i -pe 'BEGIN{undef $/;} s/plugins.*?}//smg' "$TMPF"

    # Apply the common plugins.
    echo "apply plugin: 'java'"
    echo "apply plugin: 'eclipse'"
    echo "apply plugin: 'idea'"
    if [[ "$E" == *grpc* ]]; then
      echo "apply plugin: 'com.google.protobuf'"
    fi
    echo

    # Define the repositories.
    echo 'repositories {'
    echo '    mavenCentral()'
    echo '}'
    echo

    # Import the BOM.
    echo 'dependencyManagement {'
    echo '    imports {'
    echo "        mavenBom 'io.micrometer:micrometer-bom:$MICROMETER_VERSION'"
    echo "        mavenBom 'io.netty:netty-bom:$NETTY_VERSION'"
    echo "        mavenBom 'com.linecorp.armeria:armeria-bom:$VERSION'"
    echo "        mavenBom 'org.junit:junit-bom:$JUNIT_PLATFORM_VERSION'"
    echo "        mavenBom 'io.github.resilience4j:resilience4j-bom:$RESILIENCE4J2_VERSION'"
    echo '    }'
    echo '}'
    echo

    if [[ "$E" == *grpc* ]]; then
      echo 'protobuf {'
      echo '    // Configure the protoc executable.'
      echo '    protoc {'
      echo '        // Download from the repository.'
      echo "        artifact = 'com.google.protobuf:protoc:$PROTOC_VERSION'"
      echo '    }'
      echo
      echo '    // Locate the codegen plugins.'
      echo '    plugins {'
      echo "        // Locate a plugin with name 'grpc'."
      echo '        grpc {'
      echo '            // Download from the repository.'
      echo "            artifact = 'io.grpc:protoc-gen-grpc-java:$PROTOC_GEN_GRPC_VERSION'"
      echo '        }'
      if [[ "$E" == "grpc-reactor" ]]; then
        echo "        // Locate a plugin with name 'reactorGrpc'."
        echo '        reactorGrpc {'
        echo '            // Download from the repository.'
        echo "            artifact = 'com.salesforce.servicelibs:reactor-grpc:$REACTIVE_GRPC_VERSION'"
        echo '        }'
      fi
      echo '    }'
      echo '    generateProtoTasks {'
      echo "        ofSourceSet('main')*.plugins {"
      echo '            grpc {}'
      if [[ "$E" == "grpc-reactor" ]]; then
        echo '            reactorGrpc {}'
      fi
      echo '        }'
      echo '    }'
      echo '}'
      echo
    fi

    # Add common dependencies
    echo 'dependencies {'
    echo "  implementation 'com.google.code.findbugs:jsr305:$JSR305_VERSION'"
    echo "  testImplementation 'junit:junit:$JUNIT_VERSION'"
    echo "  testImplementation 'org.assertj:assertj-core:$ASSERTJ_VERSION'"
    echo "  testImplementation 'org.junit.jupiter:junit-jupiter-api'"
    echo "  testImplementation 'org.junit.jupiter:junit-jupiter-params'"
    echo "  testRuntimeOnly 'org.junit.platform:junit-platform-commons'"
    echo "  testRuntimeOnly 'org.junit.platform:junit-platform-launcher'"
    echo "  testRuntimeOnly 'org.junit.jupiter:junit-jupiter-engine'"
    echo "  testRuntimeOnly 'org.junit.vintage:junit-vintage-engine'"
    echo '}'
    echo

    # Paste the patched file while removing the redundant empty lines.
    perl -e '
      undef $/; $_=<>;
      s/^(\r?\n)*//;
      s/(\r?\n)(\r?\n){2,}/\1\1/g;
      print
    ' < "$TMPF"
    echo

    # Configure the Java compiler.
    echo 'tasks.withType(JavaCompile) {'
    echo "    sourceCompatibility = '17'"
    echo "    targetCompatibility = '17'"
    echo "    options.encoding = 'UTF-8'"
    echo '    options.debug = true'
    echo "    options.compilerArgs += '-parameters'"
    echo '}'
    echo

    # Configure JUnit.
    echo 'tasks.withType(Test) {'
    echo '    useJUnitPlatform()'
    echo '}'
    echo
  } > "$E/build.gradle"
done

# Test all examples
for E in $(find_examples); do
  echo "Testing $E .."
  pushd "$E" >/dev/null
  ./gradlew -q clean check
  popd >/dev/null
done

echo "Successfully updated the examples for Armeria $VERSION"
