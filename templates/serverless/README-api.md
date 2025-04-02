# README

The properties for `Auth.Authorizers` under `AWS::Serverless::Api`
can have different types/structure, and there is no explicit selection
from the documentation in [ApiAuth](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-api-apiauth.html).
To cater this, you need to specify the authorizers type explicitly in your
sceptre config if it's not AWS_IAM, e.g.:

```yaml
...
sceptre_user_data:
  apis:
    - name: MyAPI
      stage_name: stage1
      auth:
        authorizers: aws_iam # This will produce Authorizers: AWS_IAM
...
```

or for [LambdaTokenAuthorizer](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-api-lambdatokenauthorizer.html)
/ [LambdaRequestAuthorizer](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-api-lambdarequestauthorizer.html)
Authorizers:

```yaml
...
sceptre_user_data:
  apis:
    - name: MyAPI
      stage_name: stage1
      auth:
        authorizers:
          type: lambda_token_authorizer # or lambda_request_authorizer
          function_arn: the Lambda function ARN
...
```

The same with Globals directive, e.g.:

```yaml
...
sceptre_user_data:
  globals:
    api:
      auth:
        authorizers: aws_iam # This will produce Authorizers: AWS_IAM
...
```

or for [CognitoAuthorizer](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-api-cognitoauthorizer.html):

```yaml
sceptre_user_data:
  globals:
    api:
      auth:
        authorizers:
          type: cognito_authorizer
          user_pool_arn: the user pool ARN
...
```
