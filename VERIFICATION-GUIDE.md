# Verification Guide - Kafka Startup Fix & System Health

This guide provides step-by-step commands to verify that the Kafka startup issue has been resolved and all backend services are functioning correctly.

## 🏥 Service Status Verification

### Check All Services Status
```bash
docker-compose ps
```

**Expected Output:**
All services should show `Up (healthy)` status:
- `artemis-elasticsearch` - Up (healthy)
- `artemis-kafka` - Up (healthy) ✅ *This was previously failing*
- `artemis-kibana` - Up
- `artemis-mongodb` - Up (healthy)
- `artemis-sqlserver` - Up (healthy)
- `artemis-zookeeper` - Up (healthy)

### Check Service Resource Usage
```bash
docker stats --no-stream
```

## ⚡ Kafka-Specific Verification

### 1. Test Kafka Connectivity
```bash
docker-compose exec -T kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

**Expected Output:**
Should return a comprehensive list of Kafka API versions without any AccessDeniedException errors.

### 2. List Kafka Topics
```bash
docker-compose exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

**Expected Output:**
```
__consumer_offsets
```
*Note: May show additional test topics if tests have been run*

### 3. Create Test Topic
```bash
docker-compose exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --topic verification-test --partitions 1 --replication-factor 1
```

**Expected Output:**
```
Created topic verification-test.
```

### 4. Describe Test Topic
```bash
docker-compose exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic verification-test
```

**Expected Output:**
Should show topic details including partition and replica information.

### 5. Clean Up Test Topic
```bash
docker-compose exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic verification-test
```

## 📨 Message Production & Consumption Test

### Produce Test Message
```bash
echo "Kafka verification message - $(date)" | docker-compose exec -T kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic verification-test
```

### Consume Test Message
```bash
docker-compose exec -T kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic verification-test --from-beginning --max-messages 1 --timeout-ms 5000
```

**Expected Output:**
Should display the message you produced above.

## 📋 Service Logs Inspection

### Check Recent Kafka Logs
```bash
docker-compose logs --tail=20 kafka
```

**What to Look For:**
- ✅ No `AccessDeniedException` errors
- ✅ No `InconsistentClusterIdException` errors
- ✅ Successfully connected to ZooKeeper
- ✅ Kafka server started successfully

### Check for Errors Across All Services
```bash
docker-compose logs --tail=10 | grep -i error
```

**Expected:** Should show minimal or no recent errors.

### Check Specific Service Logs
```bash
# Individual service logs
docker-compose logs --tail=10 elasticsearch
docker-compose logs --tail=10 mongodb
docker-compose logs --tail=10 sqlserver
docker-compose logs --tail=10 zookeeper
```

## 🧪 Test Suite Execution

### Run Individual Service Tests
```bash
# Test Kafka (should now work without AccessDeniedException)
pwsh ./doctor/Test-Kafka.ps1

# Test MongoDB (should work without null array errors)
pwsh ./doctor/Test-MongoDB.ps1

# Test SQL Server (should work without command execution errors)
pwsh ./doctor/Test-SqlServer.ps1

# Test Elasticsearch
pwsh ./doctor/Test-Elasticsearch.ps1

# Test Kibana
pwsh ./doctor/Test-Kibana.ps1
```

### Run Complete Test Suite
```bash
pwsh ./doctor/Run-AllTests.ps1
```

**Expected Results:**
- All services should pass basic connectivity tests
- Kafka tests should complete without permission errors
- MongoDB tests should handle null arrays safely
- SQL Server tests should execute complex queries successfully

## 🔧 Directory Permissions Check

### Verify Clean Kafka Data Directory
```bash
ls -la ./kafka/data/
```

**Expected Output:**
Clean directory owned by your user, without corrupted topic files.

### Verify Clean ZooKeeper Data Directory
```bash
ls -la ./zookeeper/data/
```

**Expected Output:**
Clean directory without stale metadata files.

### Check Docker Volumes
```bash
docker volume ls | grep artemis
docker volume inspect local-backend_kafka-data
```

## 🏥 Individual Service Health Checks

### Elasticsearch Health Check
```bash
curl -k -u elastic:changeme https://localhost:9200/_cluster/health
```

**Expected Output:**
```json
{"cluster_name":"docker-cluster","status":"yellow","timed_out":false,...}
```

### MongoDB Health Check
```bash
docker-compose exec -T mongodb mongosh --eval "db.adminCommand('ping')"
```

**Expected Output:**
```javascript
{ ok: 1 }
```

### SQL Server Health Check
```bash
docker-compose exec -T sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '@rt3m1sD3v' -Q "SELECT @@VERSION"
```

**Expected Output:**
Should return SQL Server version information.

### ZooKeeper Health Check
```bash
docker-compose exec -T zookeeper /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:2181 2>/dev/null || echo "ZooKeeper is running (connection refused expected for this command)"
```

### Kibana Health Check
```bash
curl -s http://localhost:5601/api/status | grep -o '"overall":{"level":"[^"]*"' || echo "Kibana is accessible"
```

## ✅ Success Indicators

### Primary Success Criteria
- [ ] `docker-compose ps` shows all services as `Up (healthy)`
- [ ] Kafka API versions command returns without errors
- [ ] Kafka topics can be created, listed, and described successfully
- [ ] Messages can be produced to and consumed from Kafka topics
- [ ] No `AccessDeniedException` errors in Kafka logs
- [ ] No `InconsistentClusterIdException` errors in logs

### Test Suite Success Criteria
- [ ] `./doctor/Test-Kafka.ps1` completes without permission errors
- [ ] `./doctor/Test-MongoDB.ps1` handles null arrays safely
- [ ] `./doctor/Test-SqlServer.ps1` executes complex queries successfully
- [ ] `./doctor/Run-AllTests.ps1` shows improved success rates

### System Health Criteria
- [ ] All service endpoints respond correctly
- [ ] Docker containers maintain healthy status
- [ ] No critical errors in service logs
- [ ] Data directories have correct permissions

## 🚨 Troubleshooting

### If Kafka Still Shows Issues
```bash
# Check if old metadata still exists
docker run --rm -v "$(pwd)/kafka/data:/data" ubuntu:22.04 find /data -name "meta.properties" -o -name ".lock"

# Check ZooKeeper connectivity
docker-compose exec -T kafka nc -z zookeeper 2181 && echo "ZooKeeper reachable" || echo "ZooKeeper unreachable"
```

### If Services Won't Start
```bash
# Check Docker resources
docker system df
docker system prune

# Check port conflicts
netstat -tulpn | grep -E "(9092|9200|27017|1433|2181|5601)"
```

### Complete Reset (if needed)
```bash
# Nuclear option - complete cleanup and restart
docker-compose down -v --remove-orphans
docker system prune -f
docker-compose up -d
```

## 📊 Performance Verification

### Check Resource Usage
```bash
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" --no-stream
```

### Test Message Throughput
```bash
# Simple throughput test
for i in {1..10}; do echo "Message $i - $(date)" | docker-compose exec -T kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic verification-test; done
```

---

## 📝 Notes

- This verification guide was created after resolving the Kafka AccessDeniedException startup issue
- The issue was caused by corrupted log directories, permission problems, and cluster ID mismatches
- Solution involved cleaning Kafka data, ZooKeeper metadata, and Docker volumes
- All diagnostic scripts have been enhanced with better error handling and cross-platform compatibility

**Date Created:** July 21, 2025  
**Issue Resolved:** Kafka startup with AccessDeniedException  
**Services Verified:** Kafka, ZooKeeper, Elasticsearch, Kibana, MongoDB, SQL Server