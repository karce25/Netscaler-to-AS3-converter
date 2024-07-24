$inputDirectory = "code_finder_output_folder"
Function ConvertTo-JsonOrDefault {
  param(
      [Parameter(Mandatory = $true)][Object] $Object,
      [Parameter(Mandatory = $true)][String] $DefaultJson
  )

  if ($Object) {
      return $Object | ConvertTo-Json -Compress
  } else {
      return $DefaultJson
  }
}
## Add SNAT Pool in Commons
# Iterate through each file in the input directory
Get-ChildItem -Path $inputDirectory | ForEach-Object {
    $inputFile = $_.FullName
    # Read the content of the input filess
    $content = Get-Content -Path $inputFile -Raw
    $parsedObject = ConvertFrom-Yaml -Yaml $content
    # Initialize variables to store parsed values
    $virtualAddress = $virtualPort = $type = $protocol = ""
    $persistenceType = $persistenceBackup = $lbMethod = ""
    $dnsQuery = $dnsQueryType = $persistenceValueAS3 = ""
    $serverTimeout = $clientTimeout = "300"
    $poolMembers = @()
    $lbMethodAlgorithm = "round-robin"
    $fullName = $parsedObject.name
    #extract Tenant mame from fullname
    if ($fullName -match '^[^-]+-[^-]+-([^-]+)-') {
        $tenant = $matches[1]
        Write-Host "Found tenant: $tenant"
    } else {
        Write-Host "No match found"
    }
    $protocol = $parsedObject.protocol
    #Write-Host "Found protocol: $protocol"
    $virtualAddress = $parsedObject.ipAddress
    #Write-Host "Found IP $virtualAddress"    
    $virtualPort = $parsedObject.port
    #Write-Host "Found Virtual Port $virtualPort" 
# Check if the virtual port is an asterisk (*) and change it to 0
  if ($virtualPort -eq '*') {
      $virtualPort = 0
  # Define the monitor to icmp if virtual port is '*'
      $icmpMonitor = @{
      "bigip" = "/Common/gateway_icmp"
      }
  # Convert $icmpMonitor to JSON
      $monitorJson = ConvertTo-JsonOrDefault -Object $icmpMonitor -DefaultJson '{"bigip": "/Common/tcp"}'
  } else {
  # Set default monitor JSON string
  $monitorJson = '{"bigip": "/Common/tcp"}'
  }
    $type = $parsedObject.type
    #Write-Host "Found Type $type"

    

# Assigning cert name variable

    if ($parsedObject.bindings.certs) {
      #Write-Host "In cert condition"
      foreach ($certEntry in $parsedObject.bindings.certs) {
          if ($certEntry.profileName) {     
             $certFileName = $certEntry.profileName
             break
              #Write-Host "Cert name is $certFileName"

          }
      }
  } else {
      Write-Host "No certs array found or it is empty"
  }

  #Connect the Opts

  $listenPolicy = @()

    foreach ($key in $parsedObject.opts.Keys) {
        #Write-Output "$key key equals value $($parsedObject.opts[$key])"
        if ($key -eq "-persistenceType") {
            $persistenceType = $($parsedObject.opts[$key])
            #Write-Host "Found persistenceType: $persistenceType"
            switch ($persistenceType) {
                    COOKIEINSERT { $persistenceValueAS3 += @"
                    {"bigip": "/Common/cookie"}
"@                    
                    }
                    SOURCEIP { $persistenceValueAS3 +=  @"
                    {"bigip": "/Common/source_addr"}
"@                     
                    }
                    NONE {}
                    Default {}
                }
        } elseif ($key -eq "-persistenceBackup") {
            $persistenceBackup = $($parsedObject.opts[$key])
            #Write-Host "Found persistenceBackup: $persistenceBackup"
            switch ($persistenceBackup) {
              COOKIEINSERT { $persistenceValueAS3 += @"
              {"bigip": "/Common/cookie"}
"@                    
              }
              SOURCEIP { $persistenceValueAS3 +=  @"
              {"bigip": "/Common/source_addr"}
"@                     
              }
              NONE {}
              Default {}
          }
        } elseif ($key -eq "-lbMethod") {
          $lbMethod = $($parsedObject.opts[$key])
          #Write-Host "Found lbMethod: $lbMethod"
          switch ($lbMethod) {
            ROUNDROBIN { $lbMethodAlgorithm = "round-robin" }
            LEASTCONNECTION { $lbMethodAlgorithm = "least-connections-member" }
            LEASTRESPONSETIME { $lbMethodAlgorithm = "least-connections-node" }
            TOKEN { $lbMethodAlgorithm = "least-sessions" }
            Default { $lbMethodAlgorithm = "round-robin" }
          }
        } elseif ($key -eq "-cltTimeout") {
          #Write-Host "Client Timeout $($parsedObject.opts[$key])"
          if ($($parsedObject.opts[$key]) -eq 9000) {
            $clientTimeout = "300"
          } else {
            $clientTimeout = $($parsedObject.opts[$key])
          }
        } 
          elseif ($key -eq "-Listenpolicy") {
            $listenPolicy=$parsedObject.opts[$key]
            $ports = [regex]::Matches($listenPolicy, '\((\d+)\)') | ForEach-Object {
              [int]$_.Groups[1].Value
          }

            $message = "The vs_${fullName} has the following policy $listenPolicy need to provide irule to the customer"
            $message | Out-File -FilePath "C:\Users\karce\OneDrive - F5, Inc\Documents\Consulting\FIS_combine\lrtc_non_prod_ssl_july22\listenpolicies.txt" -Append
        } 
        elseif ($key -eq "-backupVServer") {
          $backup_vserver=$parsedObject.opts[$key]
          Write-Host "The backup server is $backup_vserver"
          $message = "The vs_${fullName} has the following backup vserver $backup_vserver need to configure as a pool member with priority group of 5"
          $message | Out-File -FilePath "C:\Users\karce\OneDrive - F5, Inc\Documents\Consulting\FIS_combine\lrtc_non_prod_ssl_july22\backup_servers.txt" -Append
      } 
          elseif ($key -eq "-svrTimeout") {
          #Write-Host "Server Timeout $($parsedObject.opts[$key])"
          if ($($parsedObject.opts[$key]) -eq 9000) {
            $serverTimeout = "300"
          } else {
            $serverTimeout = $($parsedObject.opts[$key])
          }
        }
    }


  

   if ($parsedObject.bindings) {
    foreach ($key in $parsedObject.bindings.Keys) {
      if ($key -eq "service") {
    # Iterate over each item in the 'service' array
    foreach ($service in $parsedObject.bindings.service) {
      # Add a new hashtable to the $poolMembers array with the required details
      $servicePort = if ($service.port -eq '*') { 0 } else { $service.port }
      $poolMembers += @{
          "name"     = $service.address
          "port" = $servicePort
          "address"  = $service.address
      }
      if ($service.protocol -eq 'SSL'){
          $serversslAS3 =@"
			      "clientTLS": 
              {
                "bigip": "/Common/Shared/serverssl-FIS"
              },
"@ 
         $monitorAS3 =@" 
         "https" 
"@
          #Constructing the message
          #$message = "The vs_${fullName} listen on port 80 client side and 443 server side, changing declaration"
          #Writing the message to the output
          #$message | Out-File -FilePath "C:\Users\karce\OneDrive - F5, Inc\Documents\Consulting\FIS_combine\lrtc_non_prod_ssl_july22\severssl.csv" -Append

         
      } else {
          $serversslAS3 = ""
          $monitorAS3 = @"
          "http"
"@
      }


        foreach ($optkey in $service.opts.Keys) {
          if ($optkey  -eq "-cip" ){
            $cip=$service.opts[$optkey]
            #Write-Host "Value of cip is $cip"
            switch ($cip) {
              ENABLED { $cipValueAS3 = @"
              "profileHTTP": {
                "use": "/Common/Shared/http_xff_standardized"
                      },
"@                    
            #Constructing the message
            #$message = "The vs_${fullName} has XFF $cip and needs to be configured manually"
            #Writing the message to the output
            #$message | Out-File -FilePath "C:\Users\karce\OneDrive - F5, Inc\Documents\Consulting\FIS_combine\test_batch\xff.txt" -Append
              }
              DISABLED { $cipValueAS3 =""                     
              }
              NONE {}
              Default {}
          }
            #Write-Host "Value of cipValueAS3 is $cipValueAS3"
          }
         
       
          
       
    }

        
     
  }
      }
       elseif ($key -eq "serviceGroup") {
        foreach ($subkey in $parsedObject.bindings.serviceGroup.Keys) {
          #Write-Host "In Service Group Loop $subkey"
          if ($subkey -eq 'servers') {
              $length = $parsedObject.bindings.serviceGroup.servers.length
              if ($length -eq 1) {
                #Write-Host "Its a one length"
                $poolMembers += @{
                  "name" =  $($parsedObject.bindings.serviceGroup.servers.name)
                  "address" = $($parsedObject.bindings.serviceGroup.servers.address)
                  "port" = $($parsedObject.bindings.serviceGroup.servers.port)
                }
              } else {
                #Write-Host "In Service Group Servers length $length"
                for ($i = 0; $i -lt $length; $i++ ) {
                  $poolMembers += @{
                    "name" =  $($parsedObject.bindings.serviceGroup.servers[$i].name)
                    "address" = $($parsedObject.bindings.serviceGroup.servers[$i].address)
                    "port" = $($parsedObject.bindings.serviceGroup.servers[$i].port)
                  }
                }
              }
            } elseif ($subkey -eq "monitors") {
            foreach ($monelement in $parsedObject.bindings.serviceGroup.monitors.Keys) {
              #Write-Host "Monitors Found $monelement"
              switch ($monelement) { 
                -query {$dnsQuery = $($parsedObject.bindings.serviceGroup.monitors.'-query')}
                -queryType {
                   switch ($($parsedObject.bindings.serviceGroup.monitors.'-queryType')) {
                    Address {$dnsQueryType = "a"}
                   }
                -send {}
                -recv {}
                -interval {}
                }
              }
            }
          }
        }
      }
    } 
  }

# Generate pool members JSON
#Write-Host "Pool Members before JSON $poolMembers"
$poolMembersJson = ($poolMembers | ForEach-Object {
    @"
    {
      "addressDiscovery": "static",
      "shareNodes": true,
      "servicePort": $($_.port),
      "servers": [
        {
          "name": "s$($_.name)",
          "address": "$($_.address)"
        }
      ]
    }
"@
}) -join ","



    # Select the appropriate template based on the "type" and "protocol"
    #Write-Host "Selected template for protocol: $protocol" 
    $template = switch ($protocol) {
        "TCP" {
                #Write-Host "Selecting tcp template"
                @"
                {
                    "class": "AS3",
                    "action": "deploy",
                    "persist": true,
                    "declaration": {
                      "class": "ADC",
                      "schemaVersion": "3.50.0",
                      "test_tenant": {
                        "class": "Tenant",
                       "${fullName}": {
                          "class": "Application",
                          "vs_${fullName}": {
                            "class": "Service_TCP",
                            "layer4": "tcp",
                            "pool": "pool_$fullname",
                            "translateServerAddress": true,
                            "translateServerPort": true,
                            "profileTCP": {
                              "ingress": {
                                "use": "client_tcp_$fullname"
                              },
                              "egress": {
                                "use": "server_tcp_$fullname"
                              }
                            },
                            "shareAddresses": true,
                            ${cipValueAS3}
                    "virtualAddresses": [{
                      "use":"/Common/Shared/va_$virtualAddress"
                        }
                    ],
                            "virtualPort": $virtualPort,
                            "persistenceMethods": [
                            ${persistenceValueAS3}
                            ]
                          },
                          "pool_$fullname": {
                            "loadBalancingMode": "${lbMethodAlgorithm}",
                            "members": [
                                      $poolMembersJson
                            ],
                            "monitors": [
                              
                             $monitorJson
                              
                            ],
                            "class": "Pool"
                          },
                          "server_tcp_$fullname": {
                            "idleTimeout": $serverTimeout,
                            "class": "TCP_Profile"
                          },
                         "client_tcp_$fullname": {
                            "idleTimeout": $clientTimeout,
                            "class": "TCP_Profile"
                          }
                        }
                      }
                    }
                  }
"@
            }
  "ANY" {
              #Write-Host "Selecting any template"
              @"
              {
                  "class": "AS3",
                  "action": "deploy",
                  "persist": true,
                  "declaration": {
                    "class": "ADC",
                    "schemaVersion": "3.50.0",
                    "test_tenant": {
                      "class": "Tenant",
                     "${fullName}": {
                        "class": "Application",
                        "vs_${fullName}": {
                          "class": "Service_TCP",
                          "layer4": "tcp",
                          "pool": "pool_$fullname",
                          "translateServerAddress": true,
                          "translateServerPort": true,
                          "profileTCP": {
                            "ingress": {
                              "use": "client_tcp_$fullname"
                            },
                            "egress": {
                              "use": "server_tcp_$fullname"
                            }
                          },
                          "shareAddresses": true,
                          ${cipValueAS3}
                  "virtualAddresses": [{
                    "use":"/Common/Shared/va_$virtualAddress"
                      }
                  ],
                          "virtualPort": $virtualPort,
                          "persistenceMethods": [
                          ${persistenceValueAS3}
                          ]
                        },
                        "pool_$fullname": {
                          "loadBalancingMode": "${lbMethodAlgorithm}",
                          "members": [
                                    $poolMembersJson
                          ],
                          "monitors": [
                            
                           $monitorJson
                            
                          ],
                          "class": "Pool"
                        },
                        "server_tcp_$fullname": {
                          "idleTimeout": $serverTimeout,
                          "class": "TCP_Profile"
                        },
                       "client_tcp_$fullname": {
                          "idleTimeout": $clientTimeout,
                          "class": "TCP_Profile"
                        }
                      }
                    }
                  }
                }
"@
          }
"DNS_TCP" {
  #Write-Host "Selecting tcp template"
  @"
  {
      "class": "AS3",
      "action": "deploy",
      "persist": true,
      "declaration": {
        "class": "ADC",
        "schemaVersion": "3.50.0",
        "test_tenant": {
          "class": "Tenant",
         "${fullName}": {
            "class": "Application",
            "vs_${fullName}": {
              "class": "Service_TCP",
              "layer4": "tcp",
              "pool": "pool_$fullname",
              "translateServerAddress": true,
              "translateServerPort": true,
              "profileTCP": {
                "ingress": {
                  "use": "client_tcp_$fullname"
                },
                "egress": {
                  "use": "server_tcp_$fullname"
                }
              },
              "shareAddresses": true,
                    "virtualAddresses": [{
                      "use":"/Common/Shared/va_$virtualAddress"
                        }
                    ],
              "virtualPort": $virtualPort,
              "persistenceMethods": [
              ${persistenceValueAS3}
              ]
            },
            "pool_$fullname": {
              "loadBalancingMode": "${lbMethodAlgorithm}",
              "members": [
                        $poolMembersJson
              ],
              "monitors": [
               $monitorJson
              ],
              "class": "Pool"
            },
            "server_tcp_$fullname": {
              "idleTimeout": $serverTimeout,
              "class": "TCP_Profile"
            },
           "client_tcp_$fullname": {
              "idleTimeout": $clientTimeout,
              "class": "TCP_Profile"
            }
          }
        }
      }
    }
"@
}

"UDP" {
    #Write-Host "Selecting UDP template"
                @"
    {
        "class": "AS3",
        "action": "deploy",
        "persist": true,
        "declaration": {
          "class": "ADC",
          "schemaVersion": "3.50.0",
            "test_tenant": {
              "class": "Tenant",
              "${fullname}": {
                "class": "Application",
                "vs_${fullname}": {
                  "layer4": "udp",
                  "pool": "pool_$fullname",
                  "translateServerAddress": true,
                  "translateServerPort": true,
                  "class": "Service_UDP",
                  "profileUDP": {
                      "use": "client_udp_$fullname"
                  },
                  "shareAddresses": true,
                    "virtualAddresses": [{
                      "use":"/Common/Shared/va_$virtualAddress"
                        }
                    ],
                  "virtualPort": $virtualPort,
                  "persistenceMethods": [
                  ${persistenceValueAS3}
                  ]                  
                },             
                "client_udp_$fullname": {
                  "idleTimeout": $clientTimeout,
                  "class": "UDP_Profile"
                },
                "pool_$fullname": {
                    "loadBalancingMode": "${lbMethodAlgorithm}",
                    "members": [
                        $poolMembersJson
                    ],
                    "monitors": [
                        {
                          "bigip": "/Common/gateway_icmp"
                        }
                    ],
                    "class": "Pool"
                }
              }
            }
        }
    }
"@
        }
"DNS" {
    #Write-Host "Selecting UDP template"
                @"
    {
        "class": "AS3",
        "action": "deploy",
        "persist": true,
        "declaration": {
          "class": "ADC",
          "schemaVersion": "3.50.0",
            "test_tenant": {
              "class": "Tenant",
              "${fullname}": {
                "class": "Application",
                "vs_${fullname}": {
                    "layer4": "udp",
                    "pool": "pool_$fullname",
                    "translateServerAddress": true,
                    "translateServerPort": true,
                    "class": "Service_UDP",
                    "profileUDP": {
                        "use": "client_udp_$fullname"
                    },
                    "profileDNS": {
                      "use": "dns_$fullname"
                    },
                    "shareAddresses": true,
                    "virtualAddresses": [{
                      "use":"/Common/Shared/va_$virtualAddress"
                        }
                    ],
                    "virtualPort": $virtualPort,
                    "persistenceMethods": [
                    ${persistenceValueAS3}
                    ]                    
                  },          
                  "client_udp_$fullname": {
                    "idleTimeout": $clientTimeout,
                    "class": "UDP_Profile"
                  },
                  "dns_$fullname": {
                    "class": "DNS_Profile"
                  },
                  "monitor_dns_$fullname": {
                    "class": "Monitor",
                    "monitorType": "dns",
                    "queryName": "$dnsQuery",
                    "queryType": "$dnsQueryType"
                  },
                  "pool_$fullname": {
                      "loadBalancingMode": "${lbMethodAlgorithm}",
                      "members": [
                          $poolMembersJson
                      ],
                      "monitors": [
                          {
                              "use": "monitor_dns_$fullname"
                          }
                      ],
                      "class": "Pool"
                  }
                }
              }
            }
        }
"@
        }
        "SSL_BRIDGE" { 
            #Write-Host "Selecting SSL_BRIDGE template"
            @"
{
    "class": "AS3",
    "action": "deploy",
    "persist": true,
    "declaration": {
        "class": "ADC",
        "schemaVersion": "3.50.0",
        "test_tenant": {
          "class": "Tenant",
          "${fullname}": {
            "class": "Application",
            "vs_${fullname}": {
                "layer4": "tcp",
                "pool": "pool_$fullname",
                "translateServerAddress": true,
                "translateServerPort": true,
                "class": "Service_TCP",
                "profileTCP": {
                  "ingress": {
                    "use": "client_tcp_$fullname"
                  },
                  "egress": {
                    "use": "server_tcp_$fullname"
                  }
                },
                "shareAddresses": true,
                ${cipValueAS3}
                    "virtualAddresses": [{
                      "use":"/Common/Shared/va_$virtualAddress"
                        }
                    ],
                "virtualPort": $virtualPort,
                "persistenceMethods": [
                ${persistenceValueAS3}
                ]
            },
            "pool_$fullname": {
                "loadBalancingMode": "${lbMethodAlgorithm}",
                "members": [
                    $poolMembersJson
                ],
                "monitors": [
                    $monitorJson
                ],
                "class": "Pool"
            },
            "server_tcp_$fullname": {
              "idleTimeout": $serverTimeout,
              "class": "TCP_Profile"
            },
            "client_tcp_$fullname": {
              "idleTimeout": $clientTimeout,
              "class": "TCP_Profile"
            }
        }
    }
}
        }
"@
        }
        "SSL" { 
            #Write-Host "Selecting SSL template"
            @"
            {
              "class": "AS3",
              "action": "deploy",
              "persist": true,
              "declaration": {
                "class": "ADC",
                "schemaVersion": "3.50.0",
              "test_tenant": {
                "class": "Tenant",
                "${fullname}": {
                  "class": "Application",
                  "certkey-${fullname}": {
                    "class": "Certificate",
                    "passphrase": {
                      "ciphertext": "replace-passphrase-in-base64-format"
                      },
                    "certificate":{
                      "bigip":"$certFileName"
                      },
                    "privateKey":{
                      "bigip":"$certFileName"
                      },
                      "chainCA" :{
                        "bigip":"Sectigo-RSA-OVSS-CA"
                    }

                },
                  "cssl_${fullname}": {
                    "certificates": [
                      {
                        "certificate": "certkey-${fullname}"
                      }
                    ],
                    "class": "TLS_Server",
                    "cipherGroup": {
                      "bigip": "/Common/Shared/approved-cipher-group-001"
                    }
                  },
                  "vs_${fullname}": {
                    "class": "Service_HTTPS",
                    "pool": "pool_$fullname",
                    "translateServerAddress": true,
                    "translateServerPort": true,
                    "shareAddresses": true,
                    "redirect80": false,
                    "virtualAddresses": [{
                      "use":"/Common/Shared/va_$virtualAddress"
                        }
                    ],
                    "virtualPort": $virtualPort,
                    "serverTLS": "cssl_$fullname",
                    "profileTCP": {
                      "ingress": {
                        "use": "client_tcp_$fullname"
                      },
                      "egress": {
                        "use": "server_tcp_$fullname"
                      }
                    },
                    "clientTLS": {
                      "bigip": "/Common/serverssl"
                    },
                    "profileHTTP": {
                      "bigip": "/Common/Shared/http_xff_hsts_standardized"
                    },
                    "persistenceMethods": [
                      ${persistenceValueAS3}
                    ]
                  },
                  "pool_$fullname": {
                    "loadBalancingMode": "${lbMethodAlgorithm}",
                    "members": [
                      $poolMembersJson
                    ],
                    "class": "Pool",
                    "monitors": [
                      "https"
                    ]
                  },
                  "server_tcp_$fullname": {
                    "idleTimeout": $serverTimeout,
                    "class": "TCP_Profile"
                  },
                  "client_tcp_$fullname": {
                    "idleTimeout": $clientTimeout,
                    "class": "TCP_Profile"
                  }
                }
              }
            }
          }
"@
    }
    "SSL_TCP" { 
            #Write-Host "Selecting SSL template"
            @"
            {
              "class": "AS3",
              "action": "deploy",
              "persist": true,
              "declaration": {
                "class": "ADC",
                "schemaVersion": "3.50.0",
              "test_tenant": {
                "class": "Tenant",
                "${fullname}": {
                  "class": "Application",
                  "certkey-${fullname}": {
                    "class": "Certificate",
                    "passphrase": {
                      "ciphertext": "replace-passphrase-in-base64-format"
                      },
                    "certificate":{
                      "bigip":"$certFileName"
                      },
                    "privateKey":{
                      "bigip":"$certFileName"
                      }
                    
                },
                  "cssl_${fullname}": {
                    "certificates": [
                      {
                        "certificate": "certkey-${fullname}"
                      }
                    ],
                    "class": "TLS_Server",
                    "cipherGroup": {
                      "bigip": "/Common/Shared/approved-cipher-group-001"
                    }
                  },
                  "vs_${fullname}": {
                    "class": "Service_HTTPS",
                    "pool": "pool_$fullname",
                    "translateServerAddress": true,
                    "translateServerPort": true,
                    "shareAddresses": true,
                    "redirect80": false,
                    ${cipValueAS3}
                    "virtualAddresses": [{
                      "use":"/Common/Shared/va_$virtualAddress"
                        }
                    ],
                    "virtualPort": $virtualPort,
                    "serverTLS": "cssl_$fullname",
                    "profileTCP": {
                      "ingress": {
                        "use": "client_tcp_$fullname"
                      },
                      "egress": {
                        "use": "server_tcp_$fullname"
                      }
                    },
                    "clientTLS": {
                      "bigip": "/Common/serverssl"
                    },
                    "profileHTTP": {
                      "bigip": "/Common/Shared/http_xff_hsts_standardized"
                    },
                    "persistenceMethods": [
                      ${persistenceValueAS3}
                    ]
                  },
                  "pool_$fullname": {
                    "loadBalancingMode": "${lbMethodAlgorithm}",
                    "members": [
                      $poolMembersJson
                    ],
                    "class": "Pool",
                    "monitors": [
                      "https"
                    ]
                  },
                  "server_tcp_$fullname": {
                    "idleTimeout": $serverTimeout,
                    "class": "TCP_Profile"
                  },
                  "client_tcp_$fullname": {
                    "idleTimeout": $clientTimeout,
                    "class": "TCP_Profile"
                  }
                }
              }
            }
          }
"@
    }
    "HTTP" {    
        #Write-Host "Selecting HTTP template"
        @"
        {
            "class": "AS3",
            "action": "deploy",
            "persist": true,
            "declaration": {
              "class": "ADC",
              "schemaVersion": "3.50.0",
              "test_tenant": {
                "class": "Tenant",
                "${fullname}": {
                  "class": "Application",
                  "vs_${fullname}": {
                    "class": "Service_HTTP",
                    "layer4": "tcp",
                    "pool": "pool_$fullname",
                    "translateServerAddress": true,
                    "translateServerPort": true,
                    "shareAddresses": true,
                    "virtualAddresses": [{
                      "use":"/Common/Shared/va_$virtualAddress"
                        }
                    ],
                    "virtualPort": $virtualPort,
                    ${cipValueAS3}
                    "profileTCP": {
                      "ingress": {
                        "use": "client_tcp_$fullname"
                      },
                      "egress": {
                        "use": "server_tcp_$fullname"
                      }
                    },
                    ${serversslAS3}
                    "persistenceMethods": [
                    ${persistenceValueAS3}
                    ]
                  },
                  "pool_$fullname": {
                    "loadBalancingMode": "${lbMethodAlgorithm}",
                    "members": [
                      $poolMembersJson
                    ],
                    "class": "Pool",
                    "monitors": [
                      ${monitorAS3}
                    ]
                  },
                  "server_tcp_$fullname": {
                    "idleTimeout": $serverTimeout,
                    "class": "TCP_Profile"
                  },
                  "client_tcp_$fullname": {
                    "idleTimeout": $clientTimeout,
                    "class": "TCP_Profile"
                  }
                }
              }
            }
          }
"@
    }
    "REDIRECT" {    
        #Write-Host "Selecting HTTP template"
        @"
        {
            "class": "AS3",
            "action": "deploy",
            "persist": true,
            "declaration": {
              "class": "ADC",
              "schemaVersion": "3.50.0",
              "test_tenant": {
                "class": "Tenant",
                "${fullname}": {
                  "class": "Application",
                  "vs_${fullname}": {
                    "class": "Service_HTTP",
                    "layer4": "tcp",
                    "translateServerAddress": true,
                    "translateServerPort": true,
                    "shareAddresses": true,
                    "virtualAddresses": [{
                      "use":"/Common/Shared/va_$virtualAddress"
                        }
                    ],
                    "virtualPort": $virtualPort,
                    "profileHTTP": {
                      "use": "/Common/Shared/http_xff_standardized"
                    },
                    "profileTCP": {
                      "ingress": {
                        "use": "client_tcp_$fullname"
                      },
                      "egress": {
                        "use": "server_tcp_$fullname"
                      }
                    },
                    "iRules": [
                      {
                        "bigip": "/Common/_sys_https_redirect"
                      }
                    ]
                  },
                  "server_tcp_$fullname": {
                    "idleTimeout": $serverTimeout,
                    "class": "TCP_Profile"
                  },
                  "client_tcp_$fullname": {
                    "idleTimeout": $clientTimeout,
                    "class": "TCP_Profile"
                  }
                }
              }
            }
          }
"@
    }
        Default { }
    }
    #write-host "Template: $template"
    if ($template) {
        Write-Host "Conversion successful"
        # Perform the conversion using the selected template
        $convertedContent = $template

        # Write the converted content to a new file with .as3 extension
        $outputFile = $_.FullName -replace '\.([^\.]+)$', '_as3_.json'
        $convertedContent | Set-Content -Path $outputFile
    } else {
        Write-Host "Conversion failed"
    }
}
