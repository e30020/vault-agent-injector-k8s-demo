./setup.sh
./cleanup.sh


kubectl port-forward deployment/demo-app 8080:5000
http://localhost:8080/

