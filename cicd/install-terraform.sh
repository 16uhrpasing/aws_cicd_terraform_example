set -eu
#kann sein dass sudo bei manchen Linux versionen nicht funktioniert, ggf. rausnehmen
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/$release/hashicorp.repo
sudo yum -y install terraform
terraform --version