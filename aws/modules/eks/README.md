# Seup ingress controller


### Update K8 Config
```bash
# Template
# aws eks update-kubeconfig --name <cluster-name>
aws eks update-kubeconfig --name eks-cluster
```

### Check kubectls connectivity
```bash
kubectl cluster-info
```

### Setup Cluster, Service, Account 
```bash
# Check the service account alb-ingress-controller does not exist 
kubectl get sa -n kube-system

# Create service account alb-ingress-controller 
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/master/docs/examples/rbac-role.yaml

# Describe Service Account alb-ingress-controller 
kubectl describe sa alb-ingress-controller -n kube-system

# Retieve the arn IAM Role `AmazonEKSLoadBalancerControllerRole`
#tf state show module.eks.aws_iam_role.eks_albingresscontroller_role
aws iam get-role --role-name=AmazonEKSLoadBalancerControllerRole | jq -r '.Role.Arn'

# Update servicea account with annotation
kubectl annotate serviceaccount \
    -n kube-system alb-ingress-controller \
    eks.amazonaws.com/role-arn=<ARN-OF-AmazonEKSLoadBalancerControllerRole>

# Now the annotation is updated to the service account
kubectl describe sa alb-ingress-controller -n kube-system
```

### Deploy ingress controller
```bash
# Deploy ALB Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/master/docs/examples/alb-ingress-controller.yaml

# Verify Deployment
kubectl get deploy -n kube-system

# Check pods
kubectl get pods -n kube-system
# The pod alb-ingress-controller-* is errored out lets fix this

# Edit Deployment
kubectl edit deployment.apps/alb-ingress-controller -n kube-system

# Replaced cluster-name with our cluster-name eksdemo1
    . . .
    spec:
      containers:
      - args:
        - --ingress-class=alb
        - --cluster-name=<cluster-name|eks-cluster> # Add this only
    . . .
# Save and exit

# Again check pods this time it should be ok
kubectl get pods -n kube-system

# Monitor ingress logs for error
alias eks_alb_logs="kubectl logs -f $(kubectl get po -n kube-system | egrep -o 'alb-ingress-controller-[A-Za-z0-9-]+') -n kube-system"
```