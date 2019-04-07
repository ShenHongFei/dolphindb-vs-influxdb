# ------------ 安装 InfluxDB
wget https://dl.influxdata.com/influxdb/releases/influxdb_1.7.5_amd64.deb
dpkg -i influxdb_1.7.5_amd64.deb


# ------------ 程序控制
ps -elf | grep influx
ps -elf | grep chronograf

service influxdb start
service influxdb stop

influx

dstat -cmdnlgpy --socket


# ------------ 导入数据
cd /data/devices
aria2c -s 16 -x 16 http://shenhongfei.site/File/readings.zip
influx -import -path=/data/devices/readings.txt -precision=s -database=test



# ------------ 导出数据
# --- 非 CSV 格式
time influx_inspect export -database test -retention one_day -datadir /data/influxdb/data -waldir /data/influxdb/wal -out /data/devices/export.txt
# real    3m7.198s


# --- CSV 格式
time influx -database 'test' -execute 'SELECT * FROM readings where time ' -format csv > /data/devices/export.csv
# fatal error: runtime: out of memory

# time influx -database 'test' -format csv -execute "select * from readings where '2016-11-17 00:00:00' <= time and time < '2016-11-18 00:00:00'" > /data/devices/export_17.csv
for i in 1{5..8}; do
    time influx -database 'test' -format csv -execute "select * from readings where '2016-11-$i 00:00:00' <= time and time < '2016-11-$((i+1)) 00:00:00'" > /data/devices/export_$i.csv
done

# real    0m47.667s
# real    1m40.313s
# real    1m39.393s
# real    1m35.276s
# total 5 min 41 s



# ------------ 安装 Chronograf
aria2c  -s 16 -x 16 https://dl.influxdata.com/chronograf/releases/chronograf_1.7.9_amd64.deb
aria2c --min-split-size=1M -s 16 -x 16 http://shenhongfei.site/File/chronograf_1.7.9_amd64.deb
dpkg -i chronograf_1.7.9_amd64.deb



# ------------ 查看空间占用
du -sh /data/influxdb
# 1.2G

mv /var/lib/influxdb /data/influxdb

rm -rf /data/influxdb/*

ll /data/influxdb/

























































































