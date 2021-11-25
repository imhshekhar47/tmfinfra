#!/bin/bash
source aws.env

echo "+----------------------------------------------+"
echo "| SERVICE ACCOUNT (alb-ingress-controller)     |"
echo "+----------------------------------------------+"
echo "Update Kubernetes Config" 
aws eks update-kubeconfig --name eks-cluster
echo "Config updated"
kubectl cluster-info

echo "Create service account alb-ingress-controller"
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/master/docs/examples/rbac-role.yaml

IAM_ROLE_ARN=$(aws iam get-role --role-name=AmazonEKSLoadBalancerControllerRole | jq -r '.Role.Arn')
echo "AmazonEKSLoadBalancerControllerRole=${IAM_ROLE_ARN}"

echo "Update service account 'alb-ingress-controller' with IAM role annotation"
kubectl annotate serviceaccount \
    -n kube-system alb-ingress-controller \
    eks.amazonaws.com/role-arn="${IAM_ROLE_ARN}"

echo "View Service Account 'alb-ingress-controller'"
kubectl describe sa alb-ingress-controller -n kube-system


echo "+----------------------------------------------+"
echo "| DEPLOY INGRESS CONTROLLER                    |"
echo "+----------------------------------------------+"
echo "Deploy ingress controller"
# https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/master/docs/examples/alb-ingress-controller.yaml
kubectl apply -f ./utils/alb-ingress-controller.yaml

#echo "Edit Deployment and add cluster name"
#kubectl edit deployment.apps/alb-ingress-controller -n kube-system

echo "Verify Service Account"
kubectl describe sa alb-ingress-controller -n kube-system
