# Localized resources for DSC_xPSSessionConfiguration

ConvertFrom-StringData @'
    CheckEndpointMessage       = Checking if session configuration {0} exists ...
    EndpointNameMessage        = Session configuration {0} is {1}

    CheckPropertyMessage       = Checking if session configuration {0} is {1} ...
    NotDesiredPropertyMessage  = Session configuration {0} is NOT {1}, but {2}
    DesiredPropertyMessage     = Session configuration {0} is {1}
    SetPropertyMessage         = Session configuration {0} is now {1}

    WhitespacedStringMessage   = The session configuration {0} should not be white-spaced string
    StartupPathNotFoundMessage = Startup path {0} not found
    EmptyCredentialMessage     = The value of RunAsCredential can not be an empty credential
    WrongStartupScriptExtensionMessage = The startup script should have a 'ps1' extension, and not '{0}'

    GetTargetResourceStartMessage = Begin executing Get functionality on the session configuration {0}.
    GetTargetResourceEndMessage = End executing Get functionality on the session configuration {0}.
    SetTargetResourceStartMessage = Begin executing Set functionality on the session configuration {0}.
    SetTargetResourceEndMessage = End executing Set functionality on the session configuration {0}.
    TestTargetResourceStartMessage = Begin executing Test functionality on the session configuration {0}.
    TestTargetResourceEndMessage = End executing Test functionality on the session configuration {0}.

    EnsureSessionConfigurationMessage = Ensure the specified session configuration is "{0}"
'@
