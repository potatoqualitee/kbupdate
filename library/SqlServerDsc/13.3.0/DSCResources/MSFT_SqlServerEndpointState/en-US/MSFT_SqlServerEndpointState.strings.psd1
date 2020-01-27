ConvertFrom-StringData @'
    GetEndpointState = Getting state of the endpoint with the name '{0}' for the instance '{1}'.
    EndpointNotFound = The endpoint with the name '{0}' does not exist.
    EndpointErrorVerifyExist = Unexpected result when trying to verify existence of the endpoint with the name '{0}'.
    UnexpectedErrorFromGet = Got unexpected result from Get-TargetResource. No change is made.
    CurrentState = The current state of the endpoint is '{0}'.
    SetEndpointState = Changing the state of the endpoint with the name '{0}' for the instance '{1}'.
    ChangeState = Changing the state of endpoint to '{0}'.
    InDesiredState = The endpoint '{0}' is in the desired state, the state is '{1}'.
    NotInDesiredState = The endpoint '{0}' has the state '{1}', but expected the state to be '{2}'.
    TestingConfiguration = Determines the state of the endpoint with the name '{0}' for the instance '{1}'.
'@
