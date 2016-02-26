@REM Script for doing CV on windows for couchdb project

SET SKIP_UNIT_TESTS=1
SET COUCHBASE_NUM_VBUCKETS=64
SET PATH=%WORKSPACE%\install\bin;%PATH%

SET CURDIR=%~dp0
call %CURDIR%..\single-project-gerrit.bat %*

@echo.
@echo ============================================
@echo ===         Run viewmerge tests          ===
@echo ============================================

cd testrunner
python scripts/start_cluster_and_run_tests.py nmake b/resources/dev-single-node.ini conf/view-conf/py-viewmerge.conf || goto :error
python scripts/start_cluster_and_run_tests.py nmake b/resources/dev-4-nodes.ini conf/view-conf/py-viewmerge.conf || goto :error
cd ..

:end
exit /b 0

:error
@echo Previous command failed with error #%errorlevel%.
exit /b %errorlevel%
