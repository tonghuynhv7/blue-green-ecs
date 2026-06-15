#!/usr/bin/env bash
# switch-traffic.sh
# Dùng sau khi Tester xác nhận Green OK — swap listener 80 sang Green
# Usage: ./switch-traffic.sh <blue|green>

set -euo pipefail

TARGET="${1:-}"
REGION="${AWS_REGION:-ap-southeast-1}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <blue|green>"
  exit 1
fi

# Lấy ARN từ Terraform outputs
TF_OUTPUT=$(terraform -chdir="$(dirname "$0")" output -json)
TG_BLUE_ARN=$(echo "$TF_OUTPUT"  | jq -r '.tg_blue_arn.value')
TG_GREEN_ARN=$(echo "$TF_OUTPUT" | jq -r '.tg_green_arn.value')
ALB_ARN=$(aws elbv2 describe-listeners \
  --region "$REGION" \
  --query "Listeners[?Port==\`80\`].ListenerArn" \
  --output text \
  --load-balancer-arn "$(echo "$TF_OUTPUT" | jq -r '.alb_dns_name.value')" 2>/dev/null || true)

# Lấy Listener ARN của port 80 trực tiếp qua ALB
ALB_DNS=$(echo "$TF_OUTPUT" | jq -r '.alb_dns_name.value')
LISTENER_ARN=$(aws elbv2 describe-load-balancers \
  --region "$REGION" \
  --query "LoadBalancers[?DNSName==\`${ALB_DNS}\`].LoadBalancerArn" \
  --output text | xargs -I{} aws elbv2 describe-listeners \
  --region "$REGION" \
  --load-balancer-arn {} \
  --query "Listeners[?Port==\`80\`].ListenerArn" \
  --output text)

if [[ "$TARGET" == "green" ]]; then
  NEW_TG_ARN="$TG_GREEN_ARN"
  echo "Switching port 80 → GREEN ($TG_GREEN_ARN)"
elif [[ "$TARGET" == "blue" ]]; then
  NEW_TG_ARN="$TG_BLUE_ARN"
  echo "Switching port 80 → BLUE ($TG_BLUE_ARN)"
else
  echo "Invalid target: $TARGET. Use 'blue' or 'green'"
  exit 1
fi

aws elbv2 modify-listener \
  --region "$REGION" \
  --listener-arn "$LISTENER_ARN" \
  --default-actions Type=forward,TargetGroupArn="$NEW_TG_ARN"

echo "✅ Done. Port 80 now points to $TARGET."
echo "   Run: curl http://${ALB_DNS}/health"
