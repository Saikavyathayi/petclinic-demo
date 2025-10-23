pipeline {
	options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
        skipDefaultCheckout()
        timeout(time: 1, unit: 'HOURS')
    }
    agent {
        label 'DockerIO-4'
    }
	
    environment {
        scannerHome = tool 'SonarQube'
        SONARQUBE_CREDENTIALS_ID = credentials('prod-sonar-pet')
        SONARQUBE_URL = 'https://gbssonar.edst.ibm.com/sonar'
        ARTIFACTORY_CREDENTIALS_ID = credentials('artifactory-id-final')
        ARTIFACTORY_USER = credentials('artifactory-id-3')
        ARTIFACTORY_URL = 'gbsartifactory.edst.ibm.com'
        ARTIFACTORY_REPO = 'internet-banking'
        GIT_CREDENTIALS_ID = 'Gitlab-jenkins'
        GIT_URL = 'https://gbsgit.edst.ibm.com/Admin-ProjLib/liberty-demo-pet-clinic/liberty-demo.git'
        OC_TOKEN = credentials('oc-login')
        OC_PROJECT = 'fundtransfer-demo'
        OC_URL = 'https://c115-e.us-south.containers.cloud.ibm.com:32198'
        M2_HOME='/opt/tools/apache-maven-3.9.0'
        JAVA_HOME='/opt/tools/jdk-17.0.5'
        SLACK_TOKEN = credentials('demo-slack')
    }
    stages {
	    stage('Workspacecleanup') {
            steps {
                cleanWs()
            }
		}
		
       stage('git checkout'){
			steps {
                git credentialsId: "${GIT_CREDENTIALS_ID}", url: "${GIT_URL}", branch: 'dev'
            }
        }
		stage('Build'){
		    steps {
                echo 'Building..'
	            sh '''
	                #env
    	            #export PATH=$GRADLE_HOME/bin:$PATH
    	            java -version
    	            export PATH=$JAVA_HOME/bin:$PATH
    	            export PATH=$M2_HOME/bin:$PATH
    	            
    	            java -version
                    #mvn clean install
                    mvn clean
                    mvn spring-javaformat:apply
                    mvn  package -DskipTests
    	          
    	          '''
            }
           
		}

		stage('Unit/Integration Test'){
		    steps {
                echo 'unit test started..'
	            sh '''
	                
    	            #export PATH=$GRADLE_HOME/bin:$PATH
    	            export PATH=$JAVA_HOME/bin:$PATH
    	            export PATH=$M2_HOME/bin:$PATH
                    #mvn clean install
                    #mvn spring-javaformat:apply
                    #mvn test
                    mvn test verify jacoco:report
                    #echo 'maven testing'
    	           '''
		    }
		     post {
                always {
                    step([
                        $class: 'JacocoPublisher',
                        execPattern: 'target/jacoco.exec',
                        classPattern: 'target/classes',
                        sourcePattern: 'src/main/java',
                    ])
                }
            }
		}

        stage ('SonarQube Analysis'){
            steps {
                withSonarQubeEnv('GBSSONAR') {
                sh "${scannerHome}/bin/sonar-scanner "  +
                    "  -Dsonar.host.url=${SONARQUBE_URL} " +
                    "  -Dsonar.login=sqp_e98acda9ee903e163cca0e85fb77634752fcf83c " +
                    "  -Dsonar.projectKey=Spring-Petclinic " +
                    "  -Dsonar.projectName=Spring-Petclinic " +
                    "  -Dsonar.projectVersion=${BUILD_NUMBER}" +
                    "  -Dsonar.sources=. " +
                    "  -Dsonar.java.binaries=.* " +
                    "  -Dsonar.verbose=true " +
                    "  -Dsonar.junit.reportsPath=target/surefire-reports" +
                    "  -Dsonar.surefire.reportsPath=target/surefire-reports" +
                    "  -Dsonar.jacoco.reportPath=target/jacoco.exec" +
                    "  -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml" +
                    "  -Dsonar.binaries=target/classes" +
                    "  -Dsonar.java.coveragePlugin=jacoco" +
                    "  -Dsonar.exclusions=**/**/dummy.xml "
                }
            }
        }
        
        
            stage('Docker Build') {
                steps {
                    sh '''
                        export PATH=$JAVA_HOME/bin:$PATH
                        cd ${WORKSPACE}
                        docker build -f Dockerfile -t ${ARTIFACTORY_URL}/${ARTIFACTORY_REPO}/pet-clinic-latest:${BUILD_NUMBER} .
                    '''
                }
            }
           stage('Artifactory Image Push') {
                steps {
                    sh '''
                        sleep 10
                        docker login ${ARTIFACTORY_URL} -u ${ARTIFACTORY_USER} -p ${ARTIFACTORY_CREDENTIALS_ID}
                        echo "now pushing image to Jfrog artifactory........"
                        docker push ${ARTIFACTORY_URL}/${ARTIFACTORY_REPO}/pet-clinic-latest:${BUILD_NUMBER}
                    '''
                    }
            }
            stage ('UCD deploy') {
                steps {
                    echo 'started deploying in UCD'
                    step([  $class: 'UCDeployPublisher',
                    siteName: 'IBM GBS UCD',
                    component: [
                    $class: 'com.urbancode.jenkins.plugins.ucdeploy.VersionHelper$VersionBlock',
                    componentName: 'petclinic',
                    delivery: [
                    $class: 'com.urbancode.jenkins.plugins.ucdeploy.DeliveryHelper$Push',
                    pushVersion: '${BUILD_NUMBER}',
                    baseDir: 'workspace/Liberty-Pipeline/liberty-demo-pipeline/liberty-demo-pipeline',
                             ]
                              ],
                    deploy: [
                 $class: 'com.urbancode.jenkins.plugins.ucdeploy.DeployHelper$DeployBlock',
                 deployApp: 'petclinic-app',
                 deployEnv: 'DEV',
                 deployProc: 'deploy petclinic-app',
                 deployVersions: 'petclinic:${BUILD_NUMBER}',
                 deployOnlyChanged: false
                         ]
                          ])
                }
            }
			stage('Selenium-UAT test'){
		         steps {
                    echo 'Building..'
                   sh '''
                        export PATH=$JAVA_HOME/bin:$PATH
                        export PATH=$M2_HOME/bin:$PATH
                        chromedriver --version
                        mvn spring-javaformat:apply
                        mvn -Dtest=LibertyDemoSelenium test
                        mvn surefire-report:report-only

                    '''
                }
		    }
	}

    post {
        success {
                slackSend channel: 'slack-notify2',
                teamDomain: 'devsecops-ibm',
                tokenCredentialId: "${SLACK_TOKEN}",
                token: "${SLACK_TOKEN}",
                color: 'good',
                message: ":dancer: ${env.JOB_NAME} #${env.BUILD_NUMBER} ${env.BUILD_URL}"
            }
          failure {
                slackSend channel: 'slack-notify2',
                teamDomain: 'devsecops-ibm',
                tokenCredentialId: "${SLACK_TOKEN}",
                token: "${SLACK_TOKEN}",
                color: 'bad',
                message: ":bomb: ${env.JOB_NAME} #${env.BUILD_NUMBER} ${env.BUILD_URL}"
            }
          aborted {
                slackSend channel: 'slack-notify2',
                teamDomain: 'devsecops-ibm',
                tokenCredentialId: "${SLACK_TOKEN}",
                token: "${SLACK_TOKEN}",
                color: 'red',
                message: ":bomb: ${env.JOB_NAME} #${env.BUILD_NUMBER} ${env.BUILD_URL}"
            }
          always {
              script {
                withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId:'jira-jenkins-build', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD']]) {

            def commentText = "Jenkins Build Number: ${currentBuild.number} , Build Status: ${currentBuild.currentResult}"
           
            def curlCommand = """curl -D- -u $USERNAME:$PASSWORD \
                -X POST \
                --data '{"body":"${commentText}"}' \
                -H 'Content-Type: application/json' \
                https://gbsjira.edst.ibm.com/rest/api/2/issue/LST-574/comment"""

            def curlOutput = sh(script: curlCommand, returnStatus: true)
            
            if (curlOutput == 0) {
                echo "Jira comment updated successfully."
            } else {
                error "Failed to update Jira comment."
            } 
        }
            junit(
              allowEmptyResults: true,
              skipMarkingBuildUnstable: true,
              skipPublishingChecks: true,
              testResults: 'target/surefire-reports/*.xml'
            )
        }
    }
}
}
