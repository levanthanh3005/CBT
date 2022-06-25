#!/bin/bash

function upSBT() {
	microk8s kubectl apply -f kube-security.yaml
}

function upBBT() {
	template=`cat "kube-interaction.yaml" | sed "s/{{IPMASTER}}/$IPMASTER/g"`

	echo "$template" | microk8s kubectl apply -f -
}

# function upCBTv1(){
# 	microk8s kubectl apply -f kube-capacity-v1.yaml
# }

function upCBTv2(){
	template=`cat "kube-capacity-v2.yaml" | sed "s/{{IPMASTER}}/$IPMASTER/g"`

	echo "$template" | microk8s kubectl apply -f -

	# microk8s kubectl apply -f kube-capacity-v2.yaml
}

function upKafka() {
	# /Users/vanthanhle/Desktop/Tools/StudyKubernettes/RunAll/Kafka/kafka-service.yaml
	template=`cat "Kafka/kafka-service.yaml" | sed "s/{{IPMASTER}}/$IPMASTER/g"`

	echo "$template" | microk8s kubectl apply -f -
}

function downKafka() {
	# /Users/vanthanhle/Desktop/Tools/StudyKubernettes/RunAll/Kafka/kafka-service.yaml
	template=`cat "Kafka/kafka-service.yaml" | sed "s/{{IPMASTER}}/$IPMASTER/g"`

	echo "$template" | microk8s kubectl delete -f -
}

function prometheusUpdateRule() {
	echo "Prometheus update rule"
	microk8s kubectl cp prometheus.env.yaml monitoring/prometheus-k8s-0:/etc/prometheus/config_out -c config-reloader
	curl -X POST http://${IPMASTER}:9090/-/reload
	# curl -X POST http://10.10.21.113:9090/-/reload
}

function accessDashboard() {
	microk8s enable dashboard
	microk8s enable prometheus
	microk8s kubectl port-forward -n monitoring service/grafana --address 0.0.0.0 3000:3000 &
	microk8s kubectl port-forward -n monitoring service/prometheus-k8s --address 0.0.0.0 9090:9090 &
	microk8s kubectl proxy --accept-hosts=.* --address=0.0.0.0 & #For dashboard

	echo "Access Prometheus via http://",$IPMASTER,":9090/"
	echo "Access Grafana via http://",$IPMASTER,":3000/"
	echo "----"
	echo "Turn off service"
	echo "netstat -tulp | grep kubectl"
	echo "sudo kill -9 27345"
}

function setRoleManual(){
	microk8s kubectl label node tan-km node-role.kubernetes.io/master=master
	microk8s kubectl label node tan-k2 node-role.kubernetes.io/worker=worker
	microk8s kubectl label node tan-k3 node-role.kubernetes.io/worker=worker
}

MODE=$1
shift

while [[ $# -ge 1 ]] ; do
  key="$1"
  case $key in
  --masterip )
    IPMASTER="$2"
    : ${IPMASTER:="10.10.21.113"}
    shift
    ;;
  --example )
    EXAMPLEMORE="$2"
    shift
    ;;
  --ip )
    ip="$2"
    shift
    ;;
  * )
    echo
    echo "Up: ./TMS.sh up --masterip 10.10.21.113"
    echo
    exit 1
    ;;
  esac
  shift
done

echo "MODE:"${MODE}

if [ "${MODE}" == "up" ]; then
	# ./TMS.sh up --masterip 10.10.21.113
	echo "Up TMS System"
    upSBT
    upBBT
    upCBTv2
    prometheusUpdateRule
    accessDashboard
    setRoleManual
elif [ "${MODE}" == "upTMS" ]; then
	# ./TMS.sh upTMS --masterip 10.10.21.113
	echo "Up TMS System"
    upSBT
    upBBT
    upCBTv2
    prometheusUpdateRule
    microk8s kubectl get all --all-namespaces

elif [ "${MODE}" == "downTMS" ]; then
	echo "Up TMS System"
	microk8s kubectl delete -f kube-security.yaml
	microk8s kubectl delete -f kube-interaction.yaml
	microk8s kubectl delete -f kube-capacity-v2.yaml


elif [ "${MODE}" == "upKafka" ]; then
	# ./TMS.sh upKafka --masterip 10.10.21.113
	echo "Up Kafka and Zookeeper"
	upKafka

	echo "Export Port, add & if you want to run in background"
	echo "microk8s kubectl port-forward -n default service/kafka-service --address 0.0.0.0 9092:9092"

	echo "Run Producer"
	echo "docker run --rm --interactive  wurstmeister/kafka:2.13-2.7.1 /opt/kafka_2.13-2.7.1/bin/kafka-console-consumer.sh --topic Topic3 --from-beginning --bootstrap-server 10.10.21.113:9092"

	echo "Run Consumer"
	
	echo "docker run --rm --interactive  wurstmeister/kafka:2.13-2.7.1 /opt/kafka_2.13-2.7.1/bin/kafka-console-producer.sh --topic Topic3 --broker-list 10.10.21.113:9092"

elif [ "${MODE}" == "downKafka" ]; then
	# ./TMS.sh downKafka --masterip 10.10.21.113
	echo "Down Kafka and Zookeeper"
	downKafka

elif [ "${MODE}" == "downMicrok8s" ]; then
	echo "microk8s leave"
	echo "sudo snap remove microk8s"
elif [ "${MODE}" == "upMicrok8s" ]; then
	echo "apt-get install snapd"
	echo "sudo snap install microk8s --classic --edge"
	echo "#Show credentials to add nodes"
	echo "microk8s add-node"
	echo "#Then go to each other nodes to join the cluster"
	echo "# For Dash board:"
	echo "microk8s enable dashboard"
	echo "#"
	echo "# To skip dashboard login"
	echo "#Go to: microk8s.kubectl edit deployment/kubernetes-dashboard --namespace=kube-system"
	echo "#Then fix:"
	echo "#spec:"
	echo "#      containers:"
	echo "#      - args:"
	echo "#      - --auto-generate-certificates"
	echo "#      - --enable-skip-login"
	echo "#image: k8s.gcr.io/kubernetes-dashboard-amd64:v1.10.1"
	echo "#"
	echo "#To access dashboard:"
	echo "microk8s kubectl proxy --accept-hosts=.* --address=0.0.0.0 &"
	echo "Then go http://10.10.21.113:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/"
	echo "#"
	echo "# For Prometheus"
	echo "microk8s enable prometheus"
	echo "# >Accessing Prometheus and Grafana"
	echo "microk8s kubectl port-forward -n monitoring service/grafana --address 0.0.0.0 3000:3000 &"
	echo "microk8s kubectl port-forward -n monitoring service/prometheus-k8s --address 0.0.0.0 9090:9090 &"

	echo "# To turn off services like at 3000 or 9090"
	echo "netstat -tulp | grep kubectl"
	echo "sudo kill -9 $ServiceId"
	echo "Scenario 1:"
	echo "In 10.10.21.113:"
	echo "+ Run: ./TMS.sh example --example minerBTC-kube"
	echo "In 10.10.21.130 and 129:"
	echo "+ Run: ./TMS.sh stress-local"
	echo "Scenario 2:"
	echo "In 10.10.21.113:"
	echo "+ Run: ./TMS.sh example --example minerBTC-kube-min"
	echo "In 10.10.21.130 and 129:"
	echo "+ Run: ./TMS.sh stress-local"

elif [ "${MODE}" == "example" ]; then
	if [ "${EXAMPLEMORE}" == "deployment" ]; then
		echo "Run deployment example"

		microk8s kubectl create deployment http3 --image=katacoda/docker-http-server:latest --port=80
		microk8s kubectl expose deployment http3 --type=NodePort --name=http3 --port=3004 --target-port=80 --external-ip=${IPMASTER}

		microk8s kubectl scale --replicas=3 deployment.apps/http3

		curl ${IPMASTER}:3004

	elif [ "${EXAMPLEMORE}" == "pod" ]; then
		echo "Run pod example"

		microk8s kubectl run http --image=katacoda/docker-http-server:latest --port=80
	elif [ "${EXAMPLEMORE}" == "tpcc" ]; then
		#statements
		echo "Startup TPCC: ./TMS.sh example --masterip 10.10.21.113 --example tpccstart"
		echo "Load TPCC: ./TMS.sh example --masterip 10.10.21.113 --example tpccload"
		echo "Run TPCC: ./TMS.sh example --masterip 10.10.21.113 --example tpccrun"
		echo "Drop TPCC: ./TMS.sh example --masterip 10.10.21.113 --example tpccdrop"
		echo "Run all TPCC: ./TMS.sh example --masterip 10.10.21.113 --example tpccrunall"

	elif [ "${EXAMPLEMORE}" == "tpccstart" ]; then
		microk8s kubectl apply -f ./TPC/dropTPCC.yaml
		microk8s kubectl apply -f ./TPC/MyStatefulSet.yaml
		microk8s kubectl apply -f ./TPC/initTPCC.yaml
	elif [ "${EXAMPLEMORE}" == "tpccload" ]; then
		microk8s kubectl apply -f ./TPC/loadTPCC.yaml
	elif [ "${EXAMPLEMORE}" == "tpccrun" ]; then
		microk8s kubectl apply -f ./TPC/runTPCC.yaml
	elif [ "${EXAMPLEMORE}" == "tpccdrop" ]; then
		microk8s kubectl delete -f ./TPC/MyStatefulSet.yaml
		microk8s kubectl delete -f ./TPC/dropTPCC.yaml
		microk8s kubectl delete -f ./TPC/loadTPCC.yaml
		microk8s kubectl delete -f ./TPC/runTPCC.yaml
		microk8s kubectl delete -f ./TPC/initTPCC.yaml
	elif [ "${EXAMPLEMORE}" == "tpccrunall" ]; then
		echo "Run by: ./TMS.sh example --masterip 10.10.21.113 --example tpccrunall"
		echo "Drop TPCC"
		microk8s kubectl apply -f ./TPC/dropTPCC.yaml

		sleep 200
		echo "Start MySQL"
		microk8s kubectl apply -f ./TPC/MyStatefulSet.yaml
		
		sleep 200
		echo "Init TPCC"
		microk8s kubectl apply -f ./TPC/initTPCC.yaml

		sleep 200
		echo "load TPCC"
		microk8s kubectl apply -f ./TPC/loadTPCC.yaml

		sleep 200
		echo "run TPCC"
		microk8s kubectl apply -f ./TPC/runTPCC.yaml

		sleep 1000
		echo "drop TPCC"
		microk8s kubectl delete -f ./TPC/MyStatefulSet.yaml
		sleep 30

		microk8s kubectl delete -f ./TPC/dropTPCC.yaml
		sleep 30

		microk8s kubectl delete -f ./TPC/loadTPCC.yaml
		sleep 30

		microk8s kubectl delete -f ./TPC/runTPCC.yaml
		sleep 30

		microk8s kubectl delete -f ./TPC/initTPCC.yaml

	elif [ "${EXAMPLEMORE}" == "stress" ]; then
		microk8s kubectl delete -f stress.yaml
		microk8s kubectl apply -f stress.yaml

		echo "Get ip : microk8s kubectl describe pod/stresspy"
		echo "while true; do curl http://10.1.92.26:80/cpu/100000000/2; sleep 1;done"
		echo "while true; do curl http://10.1.92.26:80/ram/1/1000; done"
	elif [ "${EXAMPLEMORE}" == "stressoutside" ]; then
		docker run -d -p 3222:80 levanthanh3005/capacitystress:python-v1
		echo "while true; do curl http://10.10.21.130:3222/cpu/50000000/2; sleep 1;done"
		echo "while true; do curl http://10.10.21.130:3222/ram/1/1000; done"
	elif [ "${EXAMPLEMORE}" == "minerBTC" ]; then
		#Bitcoin mining
		docker run -d -u user1 -e THREAD=50 --name iotmalware levanthanh3005/iotmalware:v0
		# docker run -d -u user1 -e THREAD=50 levanthanh3005/iotmalware:v0
	elif [ "${EXAMPLEMORE}" == "minerBTC-kube" ]; then
		# ./TMS.sh example --example minerBTC-kube

		while true
		do
			minNumMiner=5

			# if [ "$(date +'%H')" -ge 10  ]; then echo "inside"; else echo "outside"; fi
			# if (($(date +'%H') -ge 10 && $(date +'%H') -le 17)); then echo "inside"; else echo "outside"; fi

			if [[ $(date +'%H') -ge 10 && $(date +'%H') -le 17 ]]
			then 
				echo "In Peak Hour"
				maxNumMiner=$(($RANDOM % 10 + 10))
			else 
				echo "Not in Peak Hour" 
				maxNumMiner=$(($RANDOM % 4 + 2))
				for (( c=5; c<=20 ; c++ )); do  echo "Bye $c miner";MinerName="miner"$c;microk8s kubectl delete -n default pod $MinerName;done
			fi


			echo "maxNumMiner:"$maxNumMiner
			for (( c=1; c<=maxNumMiner ; c++ ))
			do  
				echo "Welcome $c miner"
				MinerName="miner"$c
				echo $MinerName
				template=`cat "StressSupportFiles/miningBTC.yaml" | sed "s/{{MinerName}}/$MinerName/g"`
				echo "$template" | microk8s kubectl apply -f -
				sleepTime=$(($RANDOM % 3))
				echo "sleepTime up:"$sleepTime" s"
				sleep $sleepTime
			done

			sleepTime=$(($RANDOM % 3600)) #1 hours
			sleep $sleepTime

			for (( c=1; c<=maxNumMiner ; c++ ))
			do  
				if [ $(($RANDOM % 3)) -ge 1 ]
				then
					echo "Bye $c miner"
					MinerName="miner"$c
					echo $MinerName
					template=`cat "StressSupportFiles/miningBTC.yaml" | sed "s/{{MinerName}}/$MinerName/g"`
					echo "$template" | microk8s kubectl delete -f -
					sleepTime=$(($RANDOM % 300))
					echo "sleepTime down:"$sleepTime" s"
					sleep $sleepTime
				else
					echo "Skip deleting"
				fi
			done

			sleepTime=$(($RANDOM % 3600)) #1 hours
			sleep $sleepTime
		done
		#Delete all miners
		#maxNumMiner=40;for (( c=1; c<=maxNumMiner ; c++ )); do  echo "Welcome $c times";MinerName="miner"$c;echo $MinerName;template=`cat 	"StressSupportFiles/miningBTC.yaml" | sed "s/{{MinerName}}/$MinerName/g"`;echo "$template" | microk8s kubectl delete -f -;done
		#maxNumMiner=45;for (( c=1; c<=maxNumMiner ; c++ )); do  echo "Welcome $c times";MinerName="miner"$c;microk8s kubectl delete -n default pod $MinerName;done
	
	elif [ "${EXAMPLEMORE}" == "minerBTC-kube-min" ]; then
		# ./TMS.sh example --example minerBTC-kube-min

		microk8s kubectl apply -f ./TPC/dropTPCC.yaml
		microk8s kubectl delete -f ./TPC/runTPCC.yaml
		microk8s kubectl delete -f ./TPC/dropTPCC.yaml
		microk8s kubectl delete -f ./TPC/MyStatefulSet.yaml
		microk8s kubectl delete -f ./TPC/initTPCC.yaml
		microk8s kubectl delete -f ./TPC/loadTPCC.yaml

		microk8s kubectl apply -f ./TPC/MyStatefulSet.yaml
		microk8s kubectl apply -f ./TPC/initTPCC.yaml
		microk8s kubectl apply -f ./TPC/loadTPCC.yaml
		microk8s kubectl apply -f ./TPC/runTPCC.yaml

		while true
		do
			minNumMiner=5

			# if [ "$(date +'%H')" -ge 10  ]; then echo "inside"; else echo "outside"; fi
			# if (($(date +'%H') -ge 10 && $(date +'%H') -le 17)); then echo "inside"; else echo "outside"; fi

			if [[ $(date +'%H') -ge 10 && $(date +'%H') -le 17 ]]
			then 
				echo "In Peak Hour"
				maxNumMiner=$(($RANDOM % 5 + 5))
			else 
				echo "Not in Peak Hour" 
				maxNumMiner=$(($RANDOM % 4 + 2))
				for (( c=5; c<=20 ; c++ )); do  echo "Bye $c miner";MinerName="miner"$c;microk8s kubectl delete -n default pod $MinerName;done
				
				microk8s kubectl apply -f ./TPC/dropTPCC.yaml
				microk8s kubectl delete -f ./TPC/runTPCC.yaml
				microk8s kubectl delete -f ./TPC/dropTPCC.yaml
				microk8s kubectl delete -f ./TPC/MyStatefulSet.yaml
				microk8s kubectl delete -f ./TPC/initTPCC.yaml
				microk8s kubectl delete -f ./TPC/loadTPCC.yaml
			fi


			echo "maxNumMiner:"$maxNumMiner
			for (( c=1; c<=maxNumMiner ; c++ ))
			do  
				echo "Welcome $c miner"
				MinerName="miner"$c
				echo $MinerName
				template=`cat "StressSupportFiles/miningBTC.yaml" | sed "s/{{MinerName}}/$MinerName/g"`
				echo "$template" | microk8s kubectl apply -f -
				sleepTime=$(($RANDOM % 3))
				echo "sleepTime up:"$sleepTime" s"
				sleep $sleepTime
			done

			sleepTime=$(($RANDOM % 3600)) #1 hours
			sleep $sleepTime

			for (( c=1; c<=maxNumMiner ; c++ ))
			do  
				if [ $(($RANDOM % 3)) -ge 1 ]
				then
					echo "Bye $c miner"
					MinerName="miner"$c
					echo $MinerName
					template=`cat "StressSupportFiles/miningBTC.yaml" | sed "s/{{MinerName}}/$MinerName/g"`
					echo "$template" | microk8s kubectl delete -f -
					sleepTime=$(($RANDOM % 300))
					echo "sleepTime down:"$sleepTime" s"
					sleep $sleepTime
				else
					echo "Skip deleting"
				fi
			done

			sleepTime=$(($RANDOM % 3600)) #1 hours
			sleep $sleepTime
		done

	elif [ "${EXAMPLEMORE}" == "updateruleprometheus" ]; then
		prometheusUpdateRule
	elif [ "${EXAMPLEMORE}" == "tpccrunall2" ]; then
		echo "Run by: ./TMS.sh example --masterip 10.10.21.113 --example tpccrunall"
		echo "Drop TPCC"
		microk8s kubectl apply -f ./TPC/dropTPCC.yaml

		sleep 30
		echo "Start MySQL"
		microk8s kubectl apply -f ./TPC/MyStatefulSet.yaml
		
		sleep 100
		echo "Init TPCC"
		microk8s kubectl apply -f ./TPC/initTPCC.yaml

		sleep 100
		echo "load TPCC"
		microk8s kubectl apply -f ./TPC/loadTPCC.yaml

		sleep 200
		echo "run TPCC"
		microk8s kubectl apply -f ./TPC/runTPCC.yaml

		echo "drop TPCC"
		sleep 200
		microk8s kubectl delete -f ./TPC/runTPCC.yaml

		sleep 200
		echo "run TPCC"
		microk8s kubectl apply -f ./TPC/runTPCC.yaml

		echo "drop TPCC"
		sleep 200
		microk8s kubectl delete -f ./TPC/runTPCC.yaml

		sleep 200
		echo "run TPCC"
		microk8s kubectl apply -f ./TPC/runTPCC.yaml

		echo "drop TPCC"
		sleep 200
		microk8s kubectl delete -f ./TPC/runTPCC.yaml

		sleep 200
		echo "run TPCC"
		microk8s kubectl apply -f ./TPC/runTPCC.yaml

		sleep 1000
		echo "drop TPCC"
		microk8s kubectl delete -f ./TPC/MyStatefulSet.yaml
		sleep 30

		microk8s kubectl delete -f ./TPC/dropTPCC.yaml
		sleep 30

		microk8s kubectl delete -f ./TPC/loadTPCC.yaml
		sleep 30

		microk8s kubectl delete -f ./TPC/runTPCC.yaml
		sleep 30

		microk8s kubectl delete -f ./TPC/initTPCC.yaml

	else
		echo "Deployment : ./TMS.sh example deployment"
		echo "Pod : ./TMS.sh example pod"
		echo "Copy: scp -r /Users/vanthanhle/Desktop/Tools/StudyKubernettes/RunAll test@10.10.21.129:/home/test"
		echo 'Checking: docker run -d -p 3333:3000 -v "$(pwd):/home/project:cached" theiaide/theia:next theia browsertheia desktop'
	fi
elif [ "${MODE}" == "stress" ]; then
	#  docker run -d -p 3222:80 --name capstress levanthanh3005/capacitystress:python-v1
	#  docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' capstress
	# ./TMS.sh stress --ip 10.10.21.130:3222
	# ./TMS.sh stress --ip 10.1.92.8:80
	while true
	do
		echo "Random number:"$RANDOM
		sleepTime=$(($RANDOM % 20))
		cpuStress=$(((3000 + $RANDOM % 7000)*10000))
		cpuCount=$((1+($RANDOM % 2)))
		echo "Stress CPU to "$ip" with "$cpuStress" cpuCount "$cpuCount
		curl http://$ip/cpu/$cpuStress/$cpuCount
		echo ""
		echo "sleep "$sleepTime
		sleep $sleepTime
		if [ $cpuStress -eq 60000000 ]
		then
			ramStress=$((700 + $RANDOM % 300))

			echo "Stress RAM to "$ip" with "$ramStress
			curl http://$ip/ram/1/$ramStress
			echo ""
			# echo "sleep "$sleepTime
			# sleep $sleepTime
		fi
	done
elif [ "${MODE}" == "stress-local" ]; then
	#  docker run -d -p 3222:80 --name capstress levanthanh3005/capacitystress:python-v1
	#  docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' capstress
	# ./TMS.sh stress-local
	docker rm -f capstress

	while true
	do
		startTime=$(date +%s)
		startSecond=$(date +"%T")
		echo "Start Time:"$startTime" Start at:"$startSecond
		
		docker run -d -p 3222:80 --name capstress levanthanh3005/capacitystress:python-v1
		# docker run -d -p 3222:80 --name capstress levanthanh3005/capacitystress:python-v1
		ipStress=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' capstress)

		COUNT=$(($RANDOM % 150 + 100))
		while [ $COUNT -gt 0 ] ;do
			echo "Loop to stress:"$COUNT
			let COUNT=COUNT-1

			echo "Random number:"$RANDOM
			sleepTime=$(($RANDOM % 20 + 15))
			cpuStress=$(((1000 + $RANDOM % 2000)*100))
			cpuCount=$((1+($RANDOM % 2)))
			echo "Stress CPU to "$ipStress" with "$cpuStress" cpuCount "$cpuCount
			curl http://$ipStress/cpu/$cpuStress/$cpuCount
			echo ""
			echo "sleep "$sleepTime
			sleep $sleepTime
			if [ $cpuStress -le 200000 ]
			then
				ramStress=$((160 + $RANDOM % 80))

				echo "Stress RAM to "$ipStress" with "$ramStress
				curl http://$ipStress/ram/1/$ramStress
				echo ""
				# echo "sleep "$sleepTime
				# sleep $sleepTime
			fi
		done

		# sleepTime=$(($RANDOM % 20 + 1))
		# echo "sleep to clean"$sleepTime
		# sleep $sleepTime
		if [ $(($RANDOM % 6)) -ge  4 ]
		then
			docker rm -f capstress
			docker rmi levanthanh3005/capacitystress:python-v1
		else
			echo "Skip removing"
		fi

		sleepTime=$(($RANDOM % 2000 + 3600))

		endTime=$(date +%s)
		endSecond=$(date +"%T")
		echo "Execution time:"$((endTime - startTime))
		echo $startTime","$endTime","$startSecond","$endSecond","$((endTime - startTime))  >> malicious.csv

		echo "sleep to restart "$sleepTime

		sleep $sleepTime
	done
elif [ "${MODE}" == "stress_cpu" ]; then
	# ./TMS.sh stress --ip 10.10.21.130:3222
	# ./TMS.sh stress --ip 10.1.92.8:80
	while true
	do
		echo "Random number:"$RANDOM
		sleepTime=$(($RANDOM % 2))
		cpuStress=$(((3000 + $RANDOM % 7000)*10000))
		cpuCount=$((1+($RANDOM % 2)))
		echo "Stress CPU to "$ip" with "$cpuStress" cpuCount "$cpuCount
		curl http://$ip/cpu/$cpuStress/$cpuCount
		echo ""
		echo "sleep "$sleepTime
		sleep $sleepTime
	done
elif [ "${MODE}" == "stress_build_docker" ]; then
	# ./TMS.sh stress --ip 10.10.21.130:3222
	# ./TMS.sh stress --ip 10.1.92.8:80
	while true
	do
		docker rmi ubuntu:18.04
		docker rmi dockertestbuild2
		docker rmi dockertestbuild1
		docker rmi dockertestbuild3
		docker rmi dockertestbuild
		echo "y" | docker system prune -a

		wget -O DockerTestBuild https://raw.githubusercontent.com/levanthanh3005/eSimSubstrate/main/Docker/Dockerfile-substrate
		docker build -t dockertestbuild1 -f DockerTestBuild .

		docker rmi levanthanh3005/ns3:v0.2-py3

		git clone https://github.com/levanthanh3005/Ns3Simultech/
		cd Ns3Simultech/
		docker build -t dockertestbuild2 -f Dockerfile .
		cd ..
		rm -rf Ns3Simultech

		docker build -t dockertestbuild3 -f StressSupportFiles/Docker-tensorflow1.8 .

		docker rmi dockertestbuild2
		docker rmi dockertestbuild1
		docker rmi dockertestbuild3

		docker build -t dockertestbuild -f StressSupportFiles Docker-cv2 .
		docker rmi dockertestbuild
	done
elif [ "${MODE}" == "stress_build_docker_v2" ]; then
	# ./TMS.sh stress --ip 10.10.21.130:3222
	# ./TMS.sh stress --ip 10.1.92.8:80
	while true
	do
		docker rmi ubuntu:18.04
		docker rmi dockertestbuild2
		docker rmi dockertestbuild1
		docker rmi dockertestbuild3
		docker rmi dockertestbuild
		echo "y" | docker system prune -a

		git clone https://github.com/levanthanh3005/Ns3Simultech/
		cd Ns3Simultech/
		docker build -t dockertestbuild2 -f Dockerfile .
		cd ..
		rm -rf Ns3Simultech
		docker rmi dockertestbuild2

		docker build -t dockertestbuild3 -f StressSupportFiles/Docker-tensorflow1.8 .

		wget -O DockerTestBuild https://raw.githubusercontent.com/levanthanh3005/eSimSubstrate/main/Docker/Dockerfile-substrate
		docker build -t dockertestbuild1 -f DockerTestBuild .

		docker rmi levanthanh3005/ns3:v0.2-py3

		docker rmi dockertestbuild1
		docker rmi dockertestbuild3

		docker build -t dockertestbuild -f StressSupportFiles Docker-cv2 .
		docker rmi dockertestbuild
	done
else
    echo "no function"
fi

