using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'time-dev')
param location = readEnvironmentVariable('AZURE_LOCATION', 'centralus')
param ownerEmail = readEnvironmentVariable('OWNER_EMAIL')
param postgresAdministratorLoginPassword = readEnvironmentVariable('POSTGRES_PASSWORD')
param secretKeyBase = readEnvironmentVariable('SECRET_KEY_BASE')
