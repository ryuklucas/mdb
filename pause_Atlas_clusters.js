// Meant to be an Atlas function within Trigger to automatically pause all dedicated tier clusters on the project.
// Currently leverages Atlas Admin API Keys
// Recommended to use Trigger secrets: https://www.mongodb.com/docs/atlas/atlas-ui/triggers/functions/secrets/
// Uses Scheduled Triggers: https://www.mongodb.com/docs/atlas/atlas-ui/triggers/scheduled-triggers/

exports = async function() {
  const username = await context.values.get("AtlasPublicKey");
  const password = await context.values.get("AtlasPrivateKey");
  const projectID = "<projectId>";

  async function getClusters() {
    const arg = {
      scheme: 'https',
      host: 'cloud.mongodb.com',
      path: `/api/atlas/v2/groups/${projectID}/clusters`,
      username: username,
      password: password,
      headers: {
        'Accept': ['application/vnd.atlas.2024-08-05+json']
      },
      digestAuth: true
    };

    try {
      const response = await context.http.get(arg);
      if (response.statusCode !== 200) {
        throw new Error(`Failed to fetch clusters: ${response.body.text()}`);
      }
      const clusters = EJSON.parse(response.body.text()).results;
      return clusters;
    } catch (error) {
      console.error('Failed to fetch clusters:', error.message);
      throw error;
    }
  }

  async function pauseCluster(clusterName) {
    const arg = {
      scheme: 'https',
      host: 'cloud.mongodb.com',
      path: `/api/atlas/v2/groups/${projectID}/clusters/${clusterName}`,
      username: username,
      password: password,
      headers: {
        'Content-Type': ['application/vnd.atlas.2024-08-05+json'],
        'Accept': ['application/vnd.atlas.2024-08-05+json']
      },
      digestAuth: true,
      body: JSON.stringify({ paused: true })
    };

    try {
      const response = await context.http.patch(arg);
      if (response.statusCode !== 200) {
        throw new Error(`Failed to pause cluster ${clusterName}: ${response.body.text()}`);
      }
      console.log(`Cluster paused: ${clusterName}`);
    } catch (error) {
      console.error(`Failed to pause cluster ${clusterName}:`, error.message);
    }
  }

  async function main() {
    try {
      const clusters = await getClusters();
      for (const cluster of clusters) {
        if (cluster.paused) {
          console.log(`Skipping cluster ${cluster.name} because it is already paused`);
          continue;
        }

        if (!cluster.replicationSpecs || cluster.replicationSpecs.length === 0) {
          console.error(`No replication specs found for cluster ${cluster.name}`);
          continue;
        }

        const electableInstanceConfig = cluster.replicationSpecs[0].regionConfigs[0].electableSpecs;
        const tier = electableInstanceConfig ? electableInstanceConfig.instanceSize : null;

        if (tier) {
          console.log(`Cluster ${cluster.name} has tier ${tier}`);
          if (!["M0", "M2", "M5"].includes(tier)) {
            console.log(`Pausing cluster: ${cluster.name} with tier ${tier}`);
            await pauseCluster(cluster.name);
          } else {
            console.log(`Skipping cluster ${cluster.name} with tier ${tier}`);
          }
        } else {
          console.error(`Could not determine tier for cluster ${cluster.name}`);
        }
      }
      console.log('Applicable clusters have been processed.');
    } catch (error) {
      console.error('Error in processing clusters:', error.message);
    }
  }

  main();
}
