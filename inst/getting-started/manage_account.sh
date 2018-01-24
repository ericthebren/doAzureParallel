#!/bin/sh
# Parse arguments

programname=$0
print_usage() {
    echo "-----------------"
    echo "$programname"
    echo "-----------------"
    echo ""
    echo "Management tool for the resources required to use doAzureParallel"
    echo ""
    echo "Commands:"
    echo ""
    echo "  create:     creates a new set of resources required for doAzureParallel"
    echo "  get-keys:   get the keys required to run doAzureParallel in json format"
    echo ""
    echo "Usage:"
    echo "  create <region> [resource_group] [batch_account] [storage_account]"
    echo "      region:           <required>"
    echo "      resource_group:   [optional: default = 'doazureparallel']"
    echo "      batch_account:    [optional: default = 'doazureparallelbatch']"
    echo "      storage_account:  [optional: default = 'doazureparallelstorage']"
    echo ""
    echo "  get-keys [resource_group] [batch_account] [storage_account]"
    echo "      resource_group:   [optional: default = 'doazureparallel']"
    echo "      batch_account:    [optional: default = 'doazureparallelbatch']"
    echo "      storage_account:  [optional: default = 'doazureparallelstorage']"
    echo ""
    echo ""
    echo "Examples"
    echo "   $programname create westus"
    echo "   $programname create westus resource_group_name batch_account_name storage_account_name"
    echo "   $programname get-keys"
    echo "   $programname get-keys resource_group_name batch_account_name storage_account_name"
}

# Parameters
# $1 region
# $2 resource group
# $3 batch account
# $4 storage account
create_accounts() {
    location=$1
    resource_group=$2
    batch_account=$3
    storage_account=$4

    # Create resource group
    echo "Creating resource group."
    az group create -n $resource_group -l $location -o table

    # Create storage account
    echo "\nCreating storage account."
    az storage account create --name $storage_account --sku Standard_LRS --location $location --resource-group $resource_group -o table

    # Create batch account
    echo "\nCreating batch account."
    az batch account create --name $batch_account --location $location --resource-group $resource_group --storage-account $storage_account -o table

   echo "\nDone creating accounts. Run '$0 get-keys' to view your account credentials."
}

# Parameters
# $1 resource group
# $2 batch account
# $3 storage account
get_credentials() {
    # Get keys and urls
    resource_group=$1
    batch_account_name=$2
    storage_account_name=$3

    batch_account_key="$(az batch account keys list \
            --name $batch_account_name \
            --resource-group $resource_group \
            | jq '{key: .primary}' | jq .[])"
    batch_account_url="$(az batch account list \
            --resource-group $resource_group \
            | jq .[0].accountEndpoint)"
    storage_account_key="$(az storage account keys list \
            --account-name $storage_account_name \
            --resource-group $resource_group \
            | jq '.[0].value')"
    storage_account_url="$(az storage account show \
        --resource-group $resource_group \
        --name $storage_account_name \
        | jq .primaryEndpoints.blob)"

    export JSON='{\n
        "batchAccount": { \n
            \t"name": "'"$batch_account_name"'", \n
            \t"key": '$batch_account_key', \n
            \t"url": '$batch_account_url' \n
        }, \n
        "storageAccount": { \n
            \t"name": "'"$storage_account_name"'", \n
            \t"key": '$storage_account_key', \n
            \t"url": '$storage_account_url' \n
        }\n}'
    echo $JSON
}


# Main program
if [ "$#" -eq 0 ]; then
    # No parameters
    print_usage
    exit 1
fi

COMMAND=$1

if [ "$COMMAND" = "create" ]; then
    # Handle 'create' command
    location=$2

    if [ "$location" = "" ]; then
        echo "missing required input 'location'"
        print_usage
        exit 1
    fi

    resource_group=$3
    batch_account_name=$4
    storage_account_name=$5

    # Set defaults
    if [ "$resource_group" = "" ]; then
        resource_group="doazureparallel"
    fi

    if [ "$batch_account_name" = "" ]; then
        batch_account_name="doazureparallelbatch"
    fi

    if [ "$storage_account_name" = "" ]; then
        storage_account_name="doazureparallelstorage"
    fi

    create_accounts $location $resource_group $batch_account_name $storage_account_name
    exit 0
fi

if [ "$COMMAND" = "get-keys"  ]; then
    # Handle 'get-keys' command
    resource_group=$2
    batch_account_name=$3
    storage_account_name=$4

    # Set defaults
    if [ "$resource_group" = "" ]; then
        resource_group="doazureparallel"
    fi

    if [ "$batch_account_name" = "" ]; then
        batch_account_name="doazureparallelbatch"
    fi

    if [ "$storage_account_name" = "" ]; then
        storage_account_name="doazureparallelstorage"
    fi

    get_credentials $resource_group $batch_account_name $storage_account_name
    exit 0
fi

if [ "$COMMAND" = "-h" ] || [ "$COMMAND" = "--help" ] || [ "$COMMAND" = "h" ] |
    [ "$COMMAND" = "help" ] || [ "$COMMAND" = "?" ]; then
    # Handle 'help' command
    print_usage
    exit 0
fi

if [ "$COMMAND" != "" ]; then
    # Handle unknown commands
    echo "Unknown command '$COMMAND'"
    print_usage
    exit 1
fi

exit 0