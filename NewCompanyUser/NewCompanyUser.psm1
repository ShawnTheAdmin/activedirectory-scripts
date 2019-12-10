function new-companyaduser { 
    <#
    .SYNOPSIS
    Creates a user in Active Directory with all the necessary attributes.
    
    .DESCRIPTION
    Parameterized script that gathers some data and then creates a user within Active Directory using both predefined variables and user defined variables.
    
    .PARAMETER firstname
    Specify the users first name in title case

    .PARAMETER lastname
    Specify the users last name in title case

    .PARAMETER password
    Specify the users password to be stored as a secure string. 

    .PARAMETER title
    Specify the users job title 

    .PARAMETER manager
    Specify the users manager. This parameter can accept either Firstname Lastname or FirstInitialLastname.

    .PARAMETER username
    This is a predefined parameter. By default it will take the users first initial and full last name to  generate the username. It can be changed by using the parameter if for example there are two people with the same name.

    .PARAMETER email
    This is a predefined parameter taking the users username and appending @company.com onto it. Can be changed to custom value by calling parameter.

    .PARAMETER name
    This is a predifined parameter taking the firstname and lastname parameters and adding them together with a space. Can be changed to custom value by calling parameter.

    .PARAMETER department
    Specify the users department. This is a validate set and will only accept specific values. Tab completion works when calling the parameter manually. See accepted values in the param block.

    .PARAMETER seasonal
    This switch specifies whether the user should expire in November or not. 
    
    .EXAMPLE
    If you want to run the script and be asked for all needed values it can be ran like this: 

    new-companyaduser -verbose   

    .EXAMPLE
    If you want ot run the script and specify all the values required values but accept default values it can be ran like this: 

    new-companyaduser -firstname Foo -lastname Bar -title 'Foobar Engineer' -Manager 'FooBar Master' -Department FooStuff -verbose

    #>
    
    [CmdletBinding(SupportsShouldProcess = $true)]
    
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$firstname,
    
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$lastname,
    
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [securestring]$password,
    
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$title,
    
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$manager,
    
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$username = (($firstname).Substring(0, 1) + $lastname).ToLower(),
    
        # replace this with the actual email domain
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$email = $username + "@company.com",
    
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$name = $firstname + " " + $lastname,
    
        # Replace these with the actual department names, add more if needed.
        [Parameter(mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Department1',
            'Department2',
            'Department3',
            'Department4',
            'Department5')]

        [string]$department,
    
        [switch]$seasonal,

        [switch]$leadership
    )
    
    BEGIN {
    
        # set common variables, replace these accordingly. 
        $city = 'city'
        $company = 'company'
        $country = 'country'
        $postcode = 'zip'
        $street = 'address'
        $state = 'state'
        $msdomain = '@company.onmicrosoft.com'

        # temporarily change error action 
        $EAPreferenceBefore = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
    
    }
    
    PROCESS {

        # ensure that the user does not currently exist 
        try {
            if (Get-ADUser $username) {

                # replace this with your actual domain name
                write-host "$name already exist in domain domain.LOCAL."
                return
            }
        }
        catch {
        
        }

        # set user parameters
        $ErrorActionPreference = $EAPreferenceBefore

        $user_param = @{'GivenName' = $firstname
            'Surname'               = $lastname
            'SamAccountName'        = $username
            'UserPrincipalName'     = $email
            'AccountPassword'       = $password
            'EmailAddress'          = $email
            'Title'                 = $title
            'Description'           = $title
            'Department'            = $department
            'Company'               = $company
            'StreetAddress'         = $street
            'City'                  = $city
            'State'                 = $state
            'PostalCode'            = $postcode
            'Country'               = $country
            'CannotChangePassword'  = $false
            'PasswordNeverExpires'  = $false
            'Enabled'               = $true
            'Name'                  = $name
            'DisplayName'           = $name
        }
        
        # create the user in Active Directory
        Write-Verbose -Message "Creating $name in Active Directory."
        new-aduser @user_param 
        Start-Sleep -Seconds 10
        
        # gather user info for use in script
        $user = Get-ADUser $username -Properties Name, SamAccountName, DistinguishedName

        # move user to proper OU in Active Directory, this will need to be modified depending on structure along with switches. 
        Write-Verbose -Message "Moving user to the proper organizational unit."
        if ($PSBoundParameters.ContainsKey('department')) {
            if ($PSBoundParameters.ContainsKey('seasonal')) {
                Move-ADObject -Identity $user.DistinguishedName -TargetPath "OU=$department seasonal,DC=testdomain,DC=local"
                Add-ADGroupMember -Identity "$department Seasonal" -Members $username
            }
            elseif ($PSBoundParameters.ContainsKey('leadership')) {
                Move-ADObject -Identity $user.DistinguishedName -TargetPath "OU=$department leadership,DC=testdomain,DC=local"
                Add-ADGroupMember -Identity "$department Leadership" -Members $username
            } 
            else {
                Move-ADObject -Identity $user.DistinguishedName -TargetPath "OU=$department staff,DC=testdomain,DC=local"
                Add-ADGroupMember -Identity "$department Staff" -Members $username
            } 
        } #ifelse
    
        # set the manager in Active Directory
        Write-Verbose -Message "Setting $firstname's manager to $manager." 
        Set-ADUser -Identity $username -Manager (Get-ADUser -Identity $manager)
    
        # set user proxy addresses in Active Directory
        Write-Verbose -Message "Setting proxy address, $email will be primary."
        Set-ADUser -Identity $username -Add @{ProxyAddresses = "SMTP:$email", "smtp:$username$msdomain" }
    
    } #process
    
    END {

        # output user information 
        Write-Verbose -Message "Generating user report."
        $output = New-Object -TypeName psobject -Property $user_param
        Write-Output $output

    } #end

} #function