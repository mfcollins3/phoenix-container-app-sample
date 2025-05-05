// Copyright 2025 Neudesic, an IBM Company
//
// This program is confidential and proprietary to Neudesic, an IBM Company,
// and may not be reproduced, published, or disclosed to others without company
// authorization.

using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'time-dev')
param location = readEnvironmentVariable('AZURE_LOCATION', 'centralus')
param ownerEmail = readEnvironmentVariable('OWNER_EMAIL')
param postgresAdministratorLoginPassword = readEnvironmentVariable('POSTGRES_PASSWORD')
