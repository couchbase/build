GENERAL INFO

BUILD ${build.result}
Build URL: ${rooturl}${build.url}
Project: ${project.name}
Date of build: ${it.timestampString}
Build duration: ${build.durationString}

<% def timeout = build.getEnvironment(listener).get('TIMEOUT_VALUE').toInteger()
if (build.duration > timeout) { %>
*** BUILD TIMED OUT (POSSIBLY STUCK) ***
Build Duration: ${build.duration}
Timeout value: ${timeout}
<%
}
%>

<% def arts = build.getArtifacts()
def artdir = build.getArtifactsDir()
def junitResultList = it.JUnitTestResult
if (junitResultList.size() > 0) { %>
FAILED TESTS:
    <% junitResultList.eachWithIndex{ junitResult, index ->
      i_plus_one = index+1
      junitResult.getChildren().each { packageResult -> 
         packageResult.getFailedTests().each{ failed_test -> %>
  ${i_plus_one}. FAILED -  ${failed_test.getFullName()}
  Stack Trace: ${failed_test.getErrorStackTrace()}
        <%def tname = failed_test.getName()
          def log_folder = tname.substring(tname.indexOf("logs/testrunner"))
          def rel_log_folder = log_folder.substring(0, log_folder.indexOf(","))
          for (String art: arts) {
            if (art.startsWith(rel_log_folder)) { %>
      LOG FILE: ${rooturl}${build.url}artifact/${art}
            <% }
          }
        }
      }
    }
} %>

