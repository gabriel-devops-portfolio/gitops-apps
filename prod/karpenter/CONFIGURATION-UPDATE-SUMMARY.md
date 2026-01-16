# Karpenter Configuration Update Summary

## Changes Applied

### 1. apps-karpenter.yaml
- ✅ Updated `clusterName`: `rc-shared` → `pilotgab-prod`
- ✅ Updated `interruptionQueue`: `rc-shared` → `pilotgab-prod`
- ✅ Updated `defaultInstanceProfile`: `KarpenterNodeInstanceProfile-rc-shared` → `KarpenterNodeInstanceProfile-pilotgab-prod`
- ✅ Updated IRSA role ARN: `arn:aws:iam::485797251250:role/karpenter` → `arn:aws:iam::290793900072:role/pilotgab-prod-Karpenter-IRSA`
- ⚠️ **ACTION REQUIRED**: Replace `REPLACE_WITH_YOUR_EKS_CLUSTER_ENDPOINT` with actual EKS cluster endpoint

### 2. node-class.yaml
- ✅ Updated all discovery tags: `rc-shared` → `pilotgab-prod`
- ✅ Updated instance profiles: `KarpenterNodeInstanceProfile-rc-shared` → `KarpenterNodeInstanceProfile-pilotgab-prod`
- ✅ Applied to all 3 EC2NodeClass resources:
  - `penumbra-nodes`
  - `default`
  - `kubelet-custom`

### 3. node-pool.yaml
- ✅ Updated all node labels: `env: shared` → `env: production`
- ✅ Updated all node labels: `node.type: penumbra` → `node.type: production`
- ✅ Added `namespace: karpenter` to all NodePool resources:
  - `penumbra`
  - `on-demand-fleet`
  - `spot-fleet`
  - `default-fleet`

### 4. apps-karpenter-provisioners.yaml
- ℹ️ No changes needed (uses relative git path)

---

## Configuration Summary

**Cluster Details:**
- Cluster Name: `pilotgab-prod`
- AWS Account: `290793900072`
- Region: `us-east-1`
- Discovery Tag: `karpenter.sh/discovery: pilotgab-prod`

**IAM Resources:**
- Instance Profile: `KarpenterNodeInstanceProfile-pilotgab-prod`
- IRSA Role: `arn:aws:iam::290793900072:role/pilotgab-prod-Karpenter-IRSA`

**Node Pools:**
- `penumbra`: Compute-optimized (c/m/r), xlarge-2xlarge, on-demand, 30-day lifecycle
- `on-demand-fleet`: Mixed families, 2-8 CPUs, on-demand, consolidation enabled
- `spot-fleet`: Mixed families, 2-8 CPUs, spot instances, consolidation enabled
- `default-fleet`: Mixed families, 2-8 CPUs, on-demand, tainted, 15-min lifecycle

---

## ⚠️ Critical Actions Required

### 1. Get EKS Cluster Endpoint
Run this command to get your cluster endpoint:
```bash
aws eks describe-cluster \
  --name pilotgab-prod \
  --region us-east-1 \
  --query 'cluster.endpoint' \
  --output text
```

Then update `apps-karpenter.yaml` line 21:
```yaml
clusterEndpoint: REPLACE_WITH_YOUR_EKS_CLUSTER_ENDPOINT
```

### 2. Create Karpenter IRSA Role
The configuration expects this role: `arn:aws:iam::290793900072:role/pilotgab-prod-Karpenter-IRSA`

Add to your production `main.tf`:
```hcl
module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "pilotgab-prod-Karpenter-IRSA"

  oidc_providers = {
    main = {
      provider_arn               = module.kubernetes.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }

  role_policy_arns = {
    policy = aws_iam_policy.karpenter_controller.arn
  }

  tags = var.tags
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "pilotgab-prod-KarpenterControllerPolicy"
  description = "Policy for Karpenter controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DeleteLaunchTemplate",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = module.kubernetes.eks_managed_node_groups["internal"].iam_role_arn
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = module.kubernetes.cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "pricing:GetProducts"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:us-east-1::parameter/aws/service/*"
      }
    ]
  })
}
```

### 3. Update AMI ID (Recommended)
The configuration uses a hardcoded AMI: `ami-04bcf82576ac8eb1c`

**Option A**: Use SSM Parameter (Recommended)
```yaml
amiSelectorTerms:
  - alias: al2@latest
```

**Option B**: Update with latest EKS-optimized AMI for us-east-1
```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.31/amazon-linux-2/recommended/image_id \
  --region us-east-1 \
  --query 'Parameter.Value' \
  --output text
```

### 4. Add KMS Encryption (Security Best Practice)
Update all EC2NodeClass resources to encrypt EBS volumes:
```yaml
blockDeviceMappings:
  - deviceName: /dev/xvda
    ebs:
      volumeSize: 150Gi
      volumeType: gp3
      deleteOnTermination: true
      encrypted: true
      kmsKeyID: arn:aws:kms:us-east-1:290793900072:key/YOUR_KMS_KEY_ID
```

Get your EKS KMS key ARN from Terraform output:
```bash
terraform output -raw eks_kms_key_arn
```

### 5. Fix IMDSv2 on kubelet-custom (Security)
Update `node-class.yaml` line ~85:
```yaml
metadataOptions:
  httpEndpoint: enabled
  httpPutResponseHopLimit: 2
  httpTokens: required  # Change from 'optional' to 'required'
```

---

## Validation Steps

### 1. Verify Discovery Tags
```bash
# Check subnets
aws ec2 describe-subnets \
  --filters "Name=tag:karpenter.sh/discovery,Values=pilotgab-prod" \
  --region us-east-1 \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:karpenter.sh/discovery,Values=pilotgab-prod" \
  --region us-east-1 \
  --query 'SecurityGroups[*].[GroupId,GroupName]' \
  --output table
```

### 2. Verify Instance Profile
```bash
aws iam get-instance-profile \
  --instance-profile-name KarpenterNodeInstanceProfile-pilotgab-prod
```

### 3. Test Karpenter After Deployment
```bash
# Check controller logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=50

# Test autoscaling
kubectl run inflate --image=public.ecr.aws/eks-distro/kubernetes/pause:3.7 \
  --requests=cpu=1,memory=1Gi --replicas=20

# Watch nodes
kubectl get nodes -w
```

---

## Deployment Order

1. ✅ Apply Terraform changes (IRSA role, instance profile)
2. ✅ Update EKS cluster endpoint in `apps-karpenter.yaml`
3. ✅ Commit Karpenter configuration files to GitOps repo
4. ✅ Deploy Karpenter via ArgoCD (`apps-karpenter.yaml`)
5. ✅ Deploy Provisioners via ArgoCD (`apps-karpenter-provisioners.yaml`)
6. ✅ Validate discovery tags and controller logs
7. ✅ Test with inflate workload

---

## Security Improvements (Optional but Recommended)

1. **KMS Encryption**: Add `encrypted: true` and `kmsKeyID` to all EBS block device mappings
2. **IMDSv2 Only**: Change `httpTokens: optional` → `required` in `kubelet-custom`
3. **Latest AMI**: Use `alias: al2@latest` instead of hardcoded AMI ID
4. **Network Policies**: Add Kubernetes NetworkPolicies to restrict Karpenter controller egress
5. **Pod Security Standards**: Enforce `restricted` PSS on karpenter namespace

---

## Files Modified

- ✅ `/karpenter/apps-karpenter.yaml`
- ✅ `/karpenter/node-class.yaml`
- ✅ `/karpenter/node-pool.yaml`
- ℹ️ `/karpenter/apps-karpenter-provisioners.yaml` (no changes needed)
