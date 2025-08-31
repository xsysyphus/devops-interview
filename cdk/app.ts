#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { DevOpsInterviewStack } from './lib/devops-interview-stack';

const app = new cdk.App();

// Configurações do projeto
const projectName = app.node.tryGetContext('projectName') || 'minha-api';
const environment = app.node.tryGetContext('environment') || 'prod';

new DevOpsInterviewStack(app, 'DevOpsInterviewStack', {
  projectName,
  environment,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
  },
  description: 'DevOps Interview Challenge - ECS Fargate with mTLS Nginx Gateway'
});
