# Terraform Project for Azure Infrastructure

## Project Overview
이 프로젝트는 Azure 리소스를 관리하기 위한 Terraform 구성을 포함합니다. 주요 목적은 다음과 같습니다

- Azure 리소스 그룹 생성
- Virtual Network 및 Subnet 설정
- Network Security Group 및 Rules 설정
- Azure Storage Account 및 Data Lake 설정
- Azure Event Hubs Namespace 및 Event Hub 생성
- 기타 관련 리소스 설정


## Prerequisites
이 프로젝트를 사용하기 전에 다음 요구 사항을 충족해야 합니다

- Terraform 설치
- Azure CLI 또는 Azure 계정에 대한 액세스 권한
- Azure Subscription ID, Tenant ID 및 Service Principal 정보
- VS Code Azure Terraform Extension(권장사항)

## Set Service Principal Credentials:
```sh
export ARM_SUBSCRIPTION_ID=your_subscription_id
export ARM_TENANT_ID=your_tenant_id
export ARM_CLIENT_ID=your_client_id
export ARM_CLIENT_SECRET=your_client_secret
```

## Register Provider:
```sh
az provider register --namespace 'Microsoft.Network'
az provider register --namespace 'Microsoft.Storage'
az provider register --namespace 'Microsoft.Synapse'
az provider register --namespace 'Microsoft.Sql'
```

### 사용 방법(VS Code Azure Terraform Extension)
1. **초기화**
    Terraform을 초기화하여 필요한 provider 플러그인을 설치합니다.
    ```sh
    Azure Terraform: init
    ```

2. **유효성 검사**
    Terraform 문법을 검사합니다.
    ```sh
    Azure Terraform: validate
    ```

3. **계획**
    Terraform 계획을 생성하여 구성 변경사항을 미리 확인합니다.
    ```sh
    Azure Terraform: plan
    ```

4. **적용**
    Terraform을 사용하여 리소스를 생성 또는 변경합니다.
    ```sh
    Azure Terraform: apply
    ```

5. **정리**
    Terraform을 사용하여 생성된 리소스를 삭제합니다.
    ```sh
    Azure Terraform: destroy
    ```
