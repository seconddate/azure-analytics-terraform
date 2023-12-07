#!/bin/bash

# Microsoft 리소스 제공자 등록
az provider register --namespace 'Microsoft.Network'
az provider register --namespace 'Microsoft.Storage'
az provider register --namespace 'Microsoft.Synapse'
az provider register --namespace 'Microsoft.Sql'