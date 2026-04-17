import gql from 'graphql-tag';

// DISABLED: itPolitoCrownlabsV1alpha2TenantUpdate subscription doesn't exist in schema
// Using a minimal valid subscription as placeholder (required namespace parameter)
export default gql`
  subscription updatedTenant($tenantId: String!) {
    updatedInstance: itPolitoCrownlabsV1alpha2InstanceUpdate(namespace: $tenantId) {
      updateType
    }
  }
`;
