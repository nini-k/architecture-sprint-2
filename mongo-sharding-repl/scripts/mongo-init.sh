#!/bin/bash

echo "Инициализируем config mongo-сервер"
docker compose exec -T config_server mongosh --port 27017 --quiet <<EOF
print("running rs.initiate...");
rs.initiate(
  {
    _id: "config_server",
       configsvr: true,
    members: [
      {_id: 0, host: "config_server:27017"}
    ]
  }
);
EOF

sleep 1

echo "Инициализируем первый шард mongo"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
print("running rs.initiate...");
rs.initiate(
    {
      _id: "shard1",
      members: [
        {_id: 0, host: "shard1:27018"},
        {_id: 1, host: "shard1_1:27021"}
      ]
    }
);
EOF

sleep 1

echo "Инициализируем второй шард mongo"
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
print("running rs.initiate...");
rs.initiate(
    {
      _id: "shard2",
      members: [
        {_id :0, host: "shard2:27019"},
        {_id :1, host: "shard2_1:27022"}
      ]
    }
);
EOF

sleep 1

echo "Настраиваем работу роутера и предзаполняем мок-данные"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
print("running sh.addShard...");
sh.addShard( "shard1/shard1:27018");

print("running sh.addShard...");
sh.addShard( "shard2/shard2:27019");

print("running sh.enableSharding...");
sh.enableSharding("somedb");

print("running sh.shardCollection...");
sh.shardCollection("somedb.helloDoc", {"name": "hashed"} )

use somedb

print("running inserts mock data...");
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
EOF

echo "Кол-во элементов в primary шардах"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb;
const count = db.helloDoc.countDocuments();
print("shard1",count)
EOF
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb;
const count = db.helloDoc.countDocuments();
print("shard2",count)
EOF

echo "Кол-во элементов в репликах шардов"
docker compose exec -T shard1_1 mongosh --port 27021 --quiet <<EOF
use somedb;
const count = db.helloDoc.countDocuments();
print("replica shard1",count)
EOF
docker compose exec -T shard2_1 mongosh --port 27022 --quiet <<EOF
use somedb;
const count = db.helloDoc.countDocuments();
print("replica shard2",count)
EOF

echo "Команды выполнены перейдите на http://localhost:8080 и http://localhost:8080/docs для финальной проверки"