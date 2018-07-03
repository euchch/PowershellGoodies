# These functions assume gcConn and gcToObject from gcloudFunctions.ps1 are available to it and that all akfka servers are actual instances on GCP

# This function receives environment, the kafka servers name (partial name is acceptable), desired topics (partial name is acceptable, leave enpty for all topics) and a switch if we wish to only verify validity of topics rather than list them
function gcListKafkaTopicPartitions {
    param([Parameter(Mandatory)][string]$Environment,
    [string]$KafkaName,
	[string]$KafkaTopics,
	[switch]$TestOnly
	)

	$kafkaServer = gcGetRandomKafkaBroker -Environment $Environment -KafkaName $KafkaName
	$kafkaTopics = gcListKafkaTopics -Environment $Environment -KafkaName $KafkaName -Server $kafkaServer | Where-Object {$_ -match $KafkaTopics}
	$kafkaTopicsArray = $kafkaTopics -split ' '
	write-host "topics: $kafkaTopicsArray"
	foreach ($topic in $kafkaTopicsArray) {
		if ($TestOnly) {
			$topics = gcRunRemoteCommand -Server $kafkaServer -Command "kafka-topics --zookeeper localhost:2181 --describe --topic $topic" ; testKafkaTopicPartitions $topics
		} else {
			gcRunRemoteCommand -Server $kafkaServer -Command "kafka-topics --zookeeper localhost:2181 --describe --topic $topic"
		}
	}
}

# This one gets the output of "kafa-topics --describe" command - modify it to an object and than validates all partitions by:
# 1. testing the leader is one of the brokers listed on the partitions
# 2. testing all of Isr fields exist in "partitions"
function testKafkaTopicPartitions {
	param($TopicPartitions,
	[switch]$Verbose)
	
	$topicVerified = $true
	$delim = '|'
	$topicPartitionHeader = "Topic$($delim)Partition$($delim)Leader$($delim)Replicas$($delim)Isr"
	$firmattedTopicPartitions = $($TopicPartitions | Select-Object -Skip 1).Trim() -replace ':\s+',':' -replace '\s+',$delim -replace '[A-Z][a-z]+:',''
	$topicPartitionAsObject = $firmattedTopicPartitions | ForEach-Object -Begin {Write-Output $topicPartitionHeader} {Write-Output $_} | ConvertFrom-Csv -Delimiter $delim
	if ($Verbose) {
		Write-Host "Found $($topicPartitionAsObject.count) partitions"
	}
	foreach ($topic in $topicPartitionAsObject) {
		$topicVerified = $topicVerified -and ($topic.Leader -in $topic.Replicas.Split(','))
		if ($Verbose) {
			Write-Host "Partition: $($topic.Topic), Leader verified: $($topic.Leader -in $topic.Replicas.Split(','))"
		}
		$topicVerified = $topicVerified -and ($topic.Isr -split ',' | ForEach-Object -Begin {$result = $true} {$result = $result -and ($_ -in $topic.Replicas.Split(','))} -End {$result})
		if ($Verbose) {
			Write-Host "Partition: $($topic.Topic), Isr verified: $($topic.Isr -split ',' | ForEach-Object -Begin {result = $true} {$result = $result -and ($_ -in $topic.Replicas.Split(','))} -End {$result})"
		}
	}
	
	Write-Output "Topic: $($topicPartitionAsObject[0].Topic), Verified: $topicVerified"
}

# This one lists topics based on search string
function gcListKafkaTopics {
    param([Parameter(Mandatory)][string]$Environment,
    [string]$KafkaName,
	$Server
	)

	If ($Server -eq $null) {
		$kafkaServer = gcGetRandomKafkaBroker -Environment $Environment -KafkaName $KafkaName
	} else {
		$kafkaServer = $Server
	}
	
	gcRunRemoteCommand -Server $kafkaServer -Command 'kafka-topics --zookeeper localhost:2181 --list' | Where-Object {-not ($_ -match '^_')}

}

# This one runs desired command on gcloud instance
function gcRunRemoteCommand {
    param([Parameter(Mandatory)]$Server,
    [Parameter(Mandatory)][string]$Command
	)

	$dvEnv = ""

    switch ($Environment) {
        "dev" {$dvEnv = $dvDevProject}
        "staging" {$dvEnv = $dvStagingProject}
        "prod" {$dvEnv = $dvProdProject}
        default {Write-Output "Please select 'dev', 'staging' or 'prod' environments"}
    }
	
	gcloud compute --project $dvEnv ssh --zone $($Server.ZONE) $($Server.NAME) --command $Command

}

# Choosing a random kafka broker to query about topics and their partitions
function gcGetRandomKafkaBroker {
    param([Parameter(Mandatory)][string]$Environment,
    [string]$KafkaName
	)
	
	if ([string]::IsNullOrEmpty($KafkaName)) {
        $KafkaName = 'kafkacluster'
    }

	$dvEnv = ""

    switch ($Environment) {
        "dev" {$dvEnv = $dvDevProject}
        "staging" {$dvEnv = $dvStagingProject}
        "prod" {$dvEnv = $dvProdProject}
        default {Write-Output "Please select 'dev', 'staging' or 'prod' environments"}
    }
	gcConn $Environment
	$kafkaServer = gcToObject "gcloud compute instances list" | Where-Object { $_.NAME -match $KafkaName} | Get-Random
	return $kafkaServer
}
