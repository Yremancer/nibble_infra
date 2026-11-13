#!/bin/sh
set -eu

mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
mc mb --ignore-existing "local/$S3_BUCKET"

cat > /tmp/nibble-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetBucketLocation", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::$S3_BUCKET"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::$S3_BUCKET/*"]
    }
  ]
}
EOF

mc admin policy create local nibble-backend /tmp/nibble-policy.json
mc admin user add local "$S3_ACCESS_KEY_ID" "$S3_SECRET_ACCESS_KEY"
if ! result=$(mc admin policy attach local nibble-backend --user "$S3_ACCESS_KEY_ID" 2>&1); then
    case "$result" in
        *"Specified policy update has no net effect"*) ;;
        *) printf '%s\n' "$result" >&2; exit 1 ;;
    esac
fi
