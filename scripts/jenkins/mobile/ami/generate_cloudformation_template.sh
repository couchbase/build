
wget https://raw.githubusercontent.com/couchbaselabs/sg-autoscale/master/src/sgautoscale_cloudformation_template.py
python cloudformation_template.py

# to start cloudformation
# python cloudformation_template.py && aws cloudformation create-stack --stack-name "TleydenAmiStack2" --template-body "file://generated_cloudformation_template.json" --region us-east-1 --parameters ParameterKey=KeyName,ParameterValue=tleyden ParameterKey=SyncGatewayInstanceType,ParameterValue=m3.medium ParameterKey=SgAccelInstanceType,ParameterValue=m3.medium ParameterKey=CouchbaseServerInstanceType,ParameterValue=m3.medium
