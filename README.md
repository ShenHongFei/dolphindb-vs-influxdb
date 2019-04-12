# DolphinDB vs InfluxDB 性能对比测试报告
## 一、概述

### DolphinDB
DolphinDB 是以 C++ 编写的一款分析型的高性能分布式时序数据库，使用高吞吐低延迟的列式内存引擎，集成了功能强大的编程语言和高容量高速度的流数据分析系统，可在数据库中进行复杂的编程和运算，显著减少数据迁移所耗费的时间。  
DolphinDB 通过内存引擎、数据本地化、细粒度数据分区和并行计算实现高速的分布式计算，内置流水线、 Map Reduce 和迭代计算等多种计算框架，使用内嵌的分布式文件系统自动管理分区数据及其副本，为分布式计算提供负载均衡和容错能力。  
DolphinDB 支持类标准 SQL 的语法，提供类似于 Python 的脚本语言对数据进行操作，也提供其它常用编程语言的 API，在金融领域中的历史数据分析建模与实时流数据处理，以及物联网领域中的海量传感器数据处理与实时分析等场景中表现出色。  

### InfluxDB

InfluxDB 是目前最为流行的高性能开源时间序列数据库，由 Go 语言写成。它的核心是一款定制的存储引擎 TSM Tree，对时间序列数据做了优化，优先考虑插入和查询数据的性能。  
InfluxDB 使用类 SQL 的查询语言 InfluxQL，并提供开箱即用的时间序列数学和统计函数；同时对外提供基于 HTTP 的接口来支持数据的插入与查询  
InfluxDB 允许用户定义数据保存策略 (Retention Policies) 来实现对存储超过指定时间的数据进行删除或者降采样，被广泛应用于存储系统的监控数据，IoT 行业的实时数据等场景。

在本报告中，我们对 DolphinDB 和 InfluxDB，在时间序列数据集上进行了性能对比测试。测试涵盖了 CSV 数据文件的导入导出、磁盘空间占用、查询性能等三方面。在我们进行的所有测试中，DolphinDB 均表现的更出色，主要结论如下：

-   数据导入方面，小数据集情况下 DolphinDB 的导入性能是 InfluxDB 的 `75 倍` ，大数据集的情况下导入性能大约是其 `100 倍` ，且 InfluxDB 原生不支持 CSV 导入，需要手动转换为 Line Protocol 格式。
-   数据导出方面，DolphinDB 的性能是 InfluxDB 的 `11 倍` 左右，且 InfluxDB 在导出大批量数据为 CSV 格式时容易产生内存溢出问题。
-   磁盘空间占用方面，DolphinDB 占用的空间总是小于等于 InfluxDB 占用的空间。
-   查询功能方面，InfluxDB 不支持对比查询，不支持表连接，不支持对除 time 以外的 tag, field 进行排序，且函数的参数只能是某一个 field ，而不能是 field 的表达式，功能上有极大的限制，有多个测试样例无法在 InfluxDB 中实现；而 DolphinDB 对数据的处理则更加的灵活、方便。
-   查询性能方面，DolphinDB 在 ` 2 个` 测试样例中性能超过 InfluxDB `1000+ 倍` ；在 `6 个` 测试样例中性能超过 InfluxDB `50+ 倍` ；在 `2 个` 测试样例中性能为 InfluxDB `10+ 倍` ; 其余所有测试样例性能也全部优于 InfluxDB。

## 二、测试环境

由于 InfluxDB 集群版本闭源，在测试中 DolphinDB 与 InfluxDB 均使用单机模式

主机：DELL OptiPlex 7060  
CPU ：Intel Core i7-8700（6 核 12 线程 3.20 GHz）  
内存：32 GB （8GB × 4, 2666 MHz）  
硬盘：2T HDD （222 MB/s 读取；210 MB/s 写入）  
OS：Ubuntu 16.04 LTS  

我们测试时使用的 DolphinDB 版本为 Linux v0.89 (2019.01.31)，最大内存设置为 `28GB`

我们测试时使用的 InfluxDB 版本为 1.7.5  
根据 InfluxDB 官方配置文件中的说明，结合测试机器的实际硬件对配置做了优化，  
主要将 `wal-fsync-delay` 调节为适合机械硬盘的 `100ms`，将 `cache-max-memory-size` 设置为 `28GB`，以及将 `series-id-set-cache-size` 设置为 `400`，  
具体修改的配置详见附录中 `influxdb.conf` 文件


## 三、数据集

本报告测试了 小数据量级 (4.2 GB) 和 大数据量级 (270 GB) 下 DolphinDB 和 InfluxDB 的表现情况，以下是两个数据集的表结构和分区方法：

### 4.2 GB 设备传感器记录小数据集（CSV 格式，3 千万条）

我们使用物联网设备的传感器信息作为样例数据集来测试，数据集包含 3000 个设备在 10000 个时间间隔（2016.11.15 - 2016.11.19）上的 `传感器时间`, `设备 ID`, `电池`, `内存`, `CPU` 等时序统计信息。

来源：<https://docs.timescale.com/v1.1/tutorials/other-sample-datasets>  
下载地址：<https://timescaledata.blob.core.windows.net/datasets/devices_big.tar.gz>

数据集共 `3 × 10^7` 条数据（`4.2 GB` CSV），表结构以及分区方式如下：

### readings 表


| Column              | DolphinDB 数据类型      | InfluxDB 数据类型            |
| ------------------- | ----------------------- | ---------------------------- |
| time                | DATETIME (分区第一维度) | timestamp (second precision) |
| device_id           | SYMBOL (分区第二维度)   | tag                          |
| battery_level       | INT                     | field                        |
| battery_status      | SYMBOL                  | tag                          |
| battery_temperature | DOUBLE                  | field                        |
| bssid               | SYMBOL                  | tag                          |
| cpu_avg_1min        | DOUBLE                  | field                        |
| cpu_avg_5min        | DOUBLE                  | field                        |
| cpu_avg_15min       | DOUBLE                  | field                        |
| mem_free            | LONG                    | field                        |
| mem_used            | LONG                    | field                        |
| rssi                | SHORT                   | field                        |
| ssid                | SYMBOL                  | tag                          |


我们在 DolphinDB 中的分区方案是将 `time` 作为分区的第一个维度，按天分为 4 个区，分区边界为 `[2016.11.15 00:00:00, 2016.11.16 00:00:00, 2016.11.17 00:00:00, 2016.11.18 00:00:00, 2016.11.19 00:00:00]`；再将 `device_id` 作为分区的第二个维度，每天一共分 10 个区，最后每个分区所包含的原始数据大小约为 `100 MB`。

InfluxDB 中使用 Shard Group 来存储不同时间段的数据，不同 Shard Group 对应的时间段不会重合。一个 Shard Group 中包含了大量的 Shard， Shard 才是 InfluxDB 中真正存储数据以及提供读写服务的结构。InfluxDB 采用了 Hash 分区的方法将落到同一个 Shard Group 中的数据再次进行了一次分区，即根据 hash(Series) 将时序数据映射到不同的 Shard，因此我们使用以下语句手动指定每个 Shard Group 的 Duration，在时间维度上按天分区

```sql
create retention policy one_day on test duration inf replication 1 shard duration 1d default
```


### 270 GB 股票交易大数据集（CSV 格式，23 个 CSV，65 亿条）

我们将纽约证券交易所（NYSE）提供的 2007.08.01 - 2007.08.31 一个月的股市 Level 1 报价数据作为大数据集进行测试，数据集包含 8000 多支股票在一个月内的 `交易时间`, `股票代码`, `买入价`, `卖出价`, `买入量`, `卖出量` 等报价信息。  
数据集中共有 65 亿（65,6169,3704）条报价记录，一个 CSV 中保存一个交易日的记录，该月共 23 个交易日，未压缩的 CSV 文件共计 270 GB。
来源：<https://www.nyse.com/market-data/historical>


### taq 表

| Column | DolphinDB 数据类型    | InfluxDB 数据类型   |
| ------ | --------------------- | ---------------------- |
| symbol | SYMBOL (分区第二维度) | tag |
| date   | DATE (分区第一维度)   | timestamp |
| time   | SECOND                | 与 date 合并为一个字段 |
| bid    | DOUBLE                | field  |
| ofr    | DOUBLE                | field  |
| bidsiz | INT                   | field           |
| ofrsiz | INT                   | field           |
| mode   | INT                   | tag        |
| ex     | CHAR                  | tag           |
| mmid   | SYMBOL                | tag                |

在 DolphinDB 中我们按 `date(日期)`, `symbol(股票代码)` 进行分区，每天再根据 symbol 分为 100 个分区，每个分区大概 120 MB 左右。

InfluxDB 中使用与小数据集相同的 `one_day` Retention Policy


## 四、数据导入导出测试

### 从 CSV 文件导入数据

DolphinDB 使用以下脚本导入

```c++
timer {
    for (fp in fps) {
        loadTextEx(db, `taq, `date`symbol, fp, ,schema)
        print now() + ": 已导入 " + fp
    }
}
```

4.2 GB 设备传感器记录小数据集共 `3 千万` 条数据导入用时 `20 秒`, 平均速率 `150 万条/秒`

270 GB 股票交易大数据集共 65 亿条数据（`TAQ20070801 - TAQ20070831` 23 个文件），导入用时 `38 分钟`


InfluxDB 本身不支持直接导入 CSV，只能通过 HTTP API 或者 `influx -import` 的方式导入，出于导入性能考虑，我们选择将 CSV 中的每一行先转换为 Line Protocol 格式，如：

`readings,device_id=demo000000,battery_status=discharging,bssid=A0:B1:C5:D2:E0:F3,ssid=stealth-net battery_level=96,battery_temperature=91.7,cpu_avg_1min=5.26,cpu_avg_5min=6.172,cpu_avg_15min=6.51066666666667,mem_free=650609585,mem_used=349390415,rssi=-42 1479211200`

并添加如下文件头

```
# DDL
CREATE DATABASE test
CREATE RETENTION POLICY one_day ON test DURATION INF REPLICATION 1 SHARD DURATION 1d DEFAULT

# DML
# CONTEXT-DATABASE:test
# CONTEXT-RETENTION-POLICY:one_day
```

保存到磁盘中，再通过以下命令导入

```shell
influx -import -path=/data/devices/readings.txt -precision=s -database=test
```

经过转换后，4.2 GB 设备传感器记录小数据集共 `3 千万` 条数据导入用时 `25 分钟 10 秒`, 平均速率 `2 万条/秒`

将 TAQ 数据插入到 InfluxDB 的过程中，如果多次插入时间相同 (1185923302)，tag 相同的记录 (这里是 symbol, mode, ex)，比如下面两条，即使 value 不同 (bid, ofr, bidsiz, ofrsiz)，后面的那一条记录也会覆盖前面的记录，最终数据库中只保留了最后一条记录

```
taq,symbol=A,mode=12,ex=T bid=37,ofr=54.84,bidsiz=1,ofrsiz=1 1185923302
taq,symbol=A,mode=12,ex=T bid=37,ofr=38.12,bidsiz=1,ofrsiz=1 1185923302
```

参见 https://docs.influxdata.com/influxdb/v1.7/troubleshooting/frequently-asked-questions/#how-does-influxdb-handle-duplicate-points

在 TAQ 数据集中可能某一秒钟同一个股票有大量相同类型的交易记录，InfluxDB 这样的设计存在缺陷。

要解决这个问题文档里给出了两种方法，一种是新增一个 tag 来对相同时间的数据设置不同的 tag value 手动区分，另一种是强行微调时间戳使其不同。

设置不同的 tag value 手动区分这种方法只适用于数据**完全按照时间顺序插入**的情况。在使用其他的编程语言插入数据的过程中判断该条记录的时间戳是否与上一条记录完全相同，并在插入数据库时手动指定不同的 tag value 作区分，效率低下且操作繁琐；若数据并非完全按照时间顺序插入，则无法判断当前的时间点是否已经有数据记录的存在，是否会覆盖先前的数据。

我们在本次测试中使用强行微调时间戳的方法，由于原有 TAQ 交易记录的时间精度为秒，因此我们可以在将 CSV 的数据转换至 Line Protocol 格式的过程中，在原来精确到秒的时间戳的基础上，随机加上一个毫秒值，产生一个新的精度为毫秒的伪时间戳，以防止数据冲突。

经过转换后，270 GB 股票交易大数据集（总大小 `70 GB`）所包含的 `65 亿` 条数据导入用时 `65 小时`，平均导入速率 ` 2.7 万条/秒`。


##### 导入性能如下表所示

|            数据集             |          DolphinDB          |          InfluxDB          | 导入性能 （DolphinDB / InfluxDB） |    Δ    |
| :---------------------------: | :-------------------------: | :---------------------------: | :----------------------------------: | :-----: |
| 4.2 GB 设备传感器记录小数据集 |  150 万条/秒, 共 20 秒  | 2 万条/秒, 共 25 分钟 |                75 倍               | 20 分钟 |
|    270 GB 股票交易大数据集    | 290 万条/秒, 共 38 分钟 |    2.7 万条/秒, 共 65 小时    |              98 倍                | 64 小时 |

结果显示 DolphinDB 的导入速率远大于 InfluxDB 的导入速率。在导入过程中可以观察到随着导入时间的增加，InfluxDB 的导入速率不断下降，而 DolphinDB 保持稳定。而且 InfluxDB 在导入数据时需要先编写代码将 CSV 格式文件转换为 InfluxDB 的 Line Protocol 格式，复杂繁琐，还会产生多余的中间文件占用大量空间。


### 导出数据

在 DolphinDB 中使用 `saveText((select * from readings), '/data/devices/readings_dump.csv')` 进行数据导出，用时仅需 28 秒

在 InfluxDB 中若使用 `influx -database 'test' -format csv -execute "select * from readings > /data/devices/export_15.csv` 进行数据导出内存占用会超过 30 GB，最终引发 `fatal error: runtime: out of memory`，最后采用分时间段导出 CSV 的方法

```shell
for i in 1{5..8}; do
    time influx -database 'test' -format csv -execute "select * from readings where '2016-11-$i 00:00:00' <= time and time < '2016-11-$((i+1)) 00:00:00'" > /data/devices/export_$i.csv
done
```

总共用时 `5 min 31 s`

除性能差距悬殊之外，InfluxDB 的 CSV 数据导出操作复杂，容易发生内存溢出问题，而且导出的 CSV 文件首行无字段名称，因此用户体验远不如 DolphinDB

##### 小数据集的导出性能如下表所示

|        DolphinDB         |          InfluxDB          | 导出性能 （DolphinDB / InfluxDB） |   Δ    |
| :----------------------: | :---------------------------: | :----------------------------------: | :----: |
| 107 万条/秒   共 28 秒 | 8.8 万条/秒   共 5 分钟 31 秒 |                 11 倍                 | 5 分钟 |


## 五、磁盘空间占用对比

导入数据后对 InfluxDB 和 DolphinDB 数据库占用空间的分析如下表所示

|            数据集             | DolphinDB |             InfluxDB              | 空间利用率 （DolphinDB / InfluxDB） |   Δ    |
| :---------------------------: | :-------: | :----------------------------------: | :------------------------------------: | :----: |
| 4.2 GB 设备传感器记录小数据集 |  1.2 GB   | 1.2 GB |                  1 倍                  | 6.2 GB |
|    270 GB 股票交易大数据集    |   51 GB   |             110 GB                |                  2 倍                  | 59 GB |

小数据集中 DolphinDB 的空间利用率与 InfluxDB 相近，两款数据库都对数据进行了压缩存储，压缩率大致处于同一个数量级，在 20% - 30% 之间；大数据集中 InfluxDB 对数据的压缩效果不好，占用空间为 DolphinDB 的两倍


## 六、查询测试
我们一共对比了以下八种类别的查询

-   点查询指定某一字段取值进行查询
-   范围查询针对单个或多个字段根据时间区间查询数据
-   精度查询针对不同的标签维度列进行数据聚合，实现高维或者低维的字段范围查询功能
-   聚合查询是指时序数据库有提供针对字段进行计数、平均值、求和、最大值、最小值、滑动平均值、标准差、归一等聚合类 API 支持
-   对比查询按照两个维度将表中某字段的内容重新整理为一张表格（第一个维度作为列，第二个维度作为行）
-   抽样查询指的是数据库提供数据采样的 API，可以为每一次查询手动指定采样方式进行数据的稀疏处理，防止查询时间范围太大数据量过载的问题
-   关联查询对不同的字段，在进行相同精度、相同的时间范围进行过滤查询的基础上，筛选出有关联关系的字段并进行分组
-   经典查询是实际业务中常用的查询

### 4.2 GB 设备传感器记录小数据集查询测试

| 样例 | DolphinDB 用时 | InfluxDB 用时 | 性能比 ( DolphinDB / InfluxDB ) | Δ (ms) |
| ---- | -------------- | ---------------- | ---------------------------------- | ---- |
| 1.  查询总记录数 | 2 毫秒 | 6.7 秒 | 3340 倍 | 6.6 秒 |
| 2.  点查询：按设备 ID 查询记录数 | 3 毫秒 | 7 毫秒 | 2 倍 | 4 毫秒 |
| 3.  范围查询.单分区维度：查询某时间段内的所有记录 | 7 毫秒 | 590 毫秒 | 84 倍 | 583 毫秒 |
| 4.  范围查询.多分区维度: 查询某时间段内某些设备的所有记录 | 1 毫秒 | 4 毫秒 | 4 倍 | 3 毫秒 |
| 5.  范围查询.分区及非分区维度：查询某时间段内某些设备的特定记录 | 3 毫秒 | 19 毫秒 | 6 倍 | 16 毫秒  |
| 6.  精度查询：查询各设备在每 5 min 内的内存使用量最大、最小值之差 | 65 毫秒 | 10.5 秒                  | 162 倍 | 10 秒    |
| 7.  聚合查询.单分区维度.max：设备电池最高温度 | 25 毫秒 | 1.4 秒 | 56 倍 | 1.3 秒   |
| 8.  聚合查询.多分区维度.avg：计算各时间段内设备电池平均温度 | 602 毫秒 | 25 秒 | 42 倍 | 24 秒    |
| 9.  对比查询：对比 10 个设备 24 小时中每个小时平均电量变化情况 | 2 毫秒 | 无此功能 |  |  |
| 10. 关联查询.等值连接：查询连接某个 WiFi 的所有设备的型号 | 73 毫秒 | 不支持表连接 |  |  |
| 11. 关联查询.左连接：列出所有的 WiFi，及其连接设备的型号、系统版本，并去除重复条目 | 5 毫秒 | 不支持表连接 |  |  |
| 12. 关联查询.笛卡尔积（cross join） | 261 毫秒 | 不支持表连接 |  |  |
| 13. 关联查询.全连接（full join） | 1.8 秒 | 不支持表连接 |  |  |
| 14. 经典查询：计算某时间段内高负载高电量设备的内存大小 | 15 毫秒 | 16 秒 | 1068 倍 | 16 秒 |
| 15. 经典查询：统计连接不同网络的设备的平均电量和最大、最小电量，并按平均电量降序排列 | 59 毫秒 | 不支持对 tag, field 排序 |  |  |
| 16. 经典查询：查找所有设备平均负载最高的时段，并按照负载降序排列、时间升序排列 | 32 毫秒 | 不支持对 tag, field 排序 |  |  |
| 17. 经典查询：计算各个时间段内某些设备的总负载，并将时段按总负载降序排列 | 3 毫秒 | 不支持对 tag, field 排序 |  |  |
| 18. 经典查询：查询充电设备的最近 20 条电池温度记录 | 2 毫秒 | 27 毫秒                  | 13 倍                            | 25 毫秒 |
| 19. 经典查询：未在充电的、电量小于 33% 的、平均 1 分钟内最高负载的 5 个设备的信息 | 96 毫秒 | 不支持表连接 |  |  |
| 20. 经典查询：某两个型号的设备每小时最低电量的前 20 条数据 | 70 毫秒 | 不支持 IN 关键字 |  |  |

(具体查询语句见附录小数据集测试完整脚本)

除了性能的显著差异外，InfluxDB 在功能上也不如 DolphinDB 强大，比如：

-   InfluxDB 不支持对除 time 以外的 tag, field 进行排序，即不能 `select * from taq order by <some-field>` 参见 https://github.com/influxdata/influxdb/issues/3954

-   InfluxDB 不支持对比查询，不支持表连接，无法完成许多常规 SQL 数据库支持的查询

-   InfluxDB 中函数的参数只能是某一个 field ，而不能是 field 的表达式（`field1 + field2` 等）因此只能用 subquery 先计算出表达式的值再套用函数，非常繁琐，而且需要在子查询和父查询的 where 子句中重复指定时间范围，否则会从最旧的数据记录的时间开始一直扫描到当前时间。在样例 14 中 InfluxDB 和 DolphinDB 查询语句的对比如下：

```sql
-- 14. 经典查询：计算某时间段内高负载高电量设备的内存大小
-- DolphinDB
select max(date(time)) as date,	max(mem_free + mem_used) as mem_all
from readings
where
    time <= 2016.11.18 21:00:00,
    battery_level >= 90,
    cpu_avg_1min > 90
group by hour(time), device_id

-- InfluxDB
select max(mem_total)
from (
	select mem_free + mem_used as mem_total
    from readings 
    where
        time <= '2016-11-18 21:00:00' and 
     	battery_level >= 90 and 
     	cpu_avg_1min > 90
)
where time <= '2016-11-18 21:00:00'
group by time(1h), device_id
```

### 270 GB 股票交易大数据集查询测试

查询测试的时间包含磁盘 I/O 的时间，为保证测试公平，每次启动程序测试前均通过 Linux 系统命令 `sync; echo 1,2,3 | tee /proc/sys/vm/drop_caches` 分别清除系统的页面缓存、目录项缓存和硬盘缓存，启动程序后依次执行所有测试样例一遍。

| 样例                                               | DolphinDB 用时 | InfluxDB 用时 | 性能比 ( DolphinDB / InfluxDB ) | Δ |
| -------------------------------------------------- | -------------- | ---------------- | ---------------------------------- | ------ |
| 1.  点查询：按股票代码、时间查询 | 738 毫秒 | 909 毫秒 | 1.2 倍                          | 171 毫秒 |
| 2.  范围查询：查询某时间段内的某些股票的所有记录 | 1 秒 | 结果错误 |  |  |
| 3.  top 1000 + 排序: 按 [股票代码、日期] 过滤，按 [卖出与买入价格差] 降序 排序 | 375 毫秒 | 不支持对 tag, field 排序 |  |      |
| 4.  聚合查询.单分区维度：查询每分钟的最大卖出报价、最小买入报价 | 184 毫秒 | 302 毫秒 | 1.6 倍 | 118 毫秒 |
| 5.  聚合查询.多分区维度 + 排序：按股票代码分组查询每分钟的买入报价标准差和买入数量总和 | 62 毫秒 | 不支持对 tag, field 排序 |  |      |
| 6.  经典查询：按 [多个股票代码、日期，时间范围、报价范围] 过滤，查询 [股票代码、时间、买入价、卖出价] | 16 毫秒 | 17 毫秒 | 1 倍 | 1 毫秒 |
| 7.  经典查询：按 [日期、时间范围、卖出买入价格条件、股票代码] 过滤，查询 (各个股票 每分钟) [平均变化幅度] | 16 秒 | 51 分钟 | 183 倍 | 51 分钟 |
| 8.  经典查询：计算 某天 (每个股票 每分钟) 最大卖出报价与最小买入报价之差 | 8.1 秒 | 不支持多个 selector |  |  |
| 9.  经典查询：按 [股票代码、日期段、时间段] 过滤, 查询 (每天，时间段内每分钟) 均价 | 63 毫秒 | 4.5 秒 | 71 倍 | 4.5 秒 |
| 10. 经典查询：按 [日期段、时间段] 过滤, 查询 (每股票，每天) 均价 | 16 秒 | 55 分钟 | 208 倍 | 55 分钟 |
| 11. 经典查询：计算 某个日期段 有成交记录的 (每天, 每股票) 加权均价，并按 (日期，股票代码) 排序 | 4.2 秒 | 不支持对 tag, field 排序 |  |  |

(具体查询语句见附录大数据集测试完整脚本)

-   InfluxDB 在样例 2 的查询中，对于 where 条件中选择的多个非连续的时间分区返回的结果为空，而不是各个时间分区的结果总和，如以下代码所示：

```sql
-- 2. 范围查询：查询某时间段内的某些股票的所有记录
select symbol, time, bid, ofr 
from taq 
where
	(symbol = 'IBM' or symbol = 'MSFT' or symbol = 'GOOG' or symbol = 'YHOO') and
	('2007-08-03 01:30:00' <= time and time < '2007-08-03 01:30:59')
-- 该语句返回的结果不为空

select symbol, time, bid, ofr 
from taq 
where
	(symbol = 'IBM' or symbol = 'MSFT' or symbol = 'GOOG' or symbol = 'YHOO') and
	(('2007-08-03 01:30:00' <= time and time < '2007-08-03 01:30:59') or ('2007-08-04 01:30:00' <= time and time < '2007-08-04 01:30:59'))
-- 扩展了时间范围后，该语句返回的结果反而为空
```

-   InfluxDB 无法处理样例 8 中的查询：

```sql
-- 8. 经典查询：计算 某天 (每个股票 每分钟) 最大卖出与最小买入价之差
select symbol, max(ofr) - min(bid) as gap 
from taq 
where
	'2007-08-03' <= time and time < '2007-08-04' and 
	bid > 0 and 
	ofr > bid 
group by symbol, time(1m)
```

报错 `ERR: mixing multiple selector functions with tags or fields is not supported`，即不能在 select 语句中同时使用 max 和 min 函数；而 DolphinDB 可以成功查询，这体现了 DolphinDB 对数据处理的灵活性更好

-   InfluxDB 对时间进行 group by 之后返回的结果包含了所有的时间段，即使当前时间段内无有效数据也返回，对于稀疏数据增加了处理复杂度且降低性能，如下表所示

```
2007-07-31T23:02:00Z 22.17   54.84
2007-07-31T23:03:00Z
2007-07-31T23:04:00Z
2007-07-31T23:05:00Z
2007-07-31T23:06:00Z
2007-07-31T23:07:00Z
2007-07-31T23:08:00Z 37      38.12
2007-07-31T23:09:00Z
2007-07-31T23:10:00Z 37.03   38.12
```

## 七、其它方面比较
DolphinDB 除了在基准测试中体现出优越的性能之外，还具有如下优势：  
（1）InfluxDB 通过 InfluxQL 来操作数据库，这是一种类 SQL 语言；而 DolphinDB 内置了完整的脚本语言，不仅支持 SQL 语言，而且支持命令式、向量化、函数化、元编程、RPC 等多种编程范式，可以轻松实现更多的功能。  
（2）InfluxDB 对于特定文件格式数据例如 CSV 文件的批量导入没有很好的官方支持。用户只能通过开源第三方工具或自己实现文件的读取，规整为 InfluxDB 指定的输入格式，再通过 API 进行批量导入。单次只能导入 5000 行，不仅操作复杂，效率也极其低下。与之对比，DolphinDB 的脚本语言中提供了 loadText、loadTextEx 函数，用户可以在脚本中直接导入 CSV 文件，而且效率更高，对用户更友好。  
（3）DolphinDB 提供 400 余种内置函数，可满足金融领域的历史数据建模与实时流数据处理，及物联网领域中的实时监控与数据实时分析处理等不同的场景需求。提供时序数据处理需要的领先、滞后、累积窗口、滑动窗口等多种指标的函数，且在性能上进行了优化，性能极优。 因而与 InfluxDB 相比，DolphinDB 拥有更多的适用场景。  
（4）InfluxDB 不支持表连接，而 DolphinDB 不仅支持表连接，还对 asof join 及 window join 等非同时连接方式做了优化。  
（5）InfluxDB 中，对时间序列的分组（GroupBy）最大单位是星期（week）；而 DolphinDB 支持对所有内置时间类型的分组，最大单位为月 （month）。因此在时间序列这一特性上，DolphinDB 也有更好的支持。  
（6）DolphinDB 支持事务，而且在一个分区的多个副本写入时，保证强一致性。  


## 八、附录

-   数据预览（取前 20 行）

| 数据                                     | 文件                                                   |
| ---------------------------------------- | ------------------------------------------------------ |
| readings                                 | [readings.csv](readings.csv)                           |
| readings (Line Protocol)                 | [readings.lineprotocol.txt](readings.lineprotocol.txt) |
| TAQ                                      | [TAQ.csv](TAQ.csv)                                     |
| TAQ (Line Protocol)                      | [TAQ.lineprotocol.txt](TAQ.lineprotocol.txt)           |
| 小数据 CSV -> Line Protocol 数据转换脚本 | [convert_small.coffee](convert_small.coffee)           |
| 大数据 CSV -> Line Protocol 数据转换脚本 | [convert_big.coffee](convert_big.coffee)               |

-   DolphinDB

| 脚本                 | 文件                                                 |
| -------------------- | ---------------------------------------------------- |
| 安装、配置、启动脚本 | [test_dolphindb.sh](test_dolphindb.sh)               |
| 配置文件             | [dolphindb.cfg](dolphindb.cfg)                       |
| 小数据集测试完整脚本 | [test_dolphindb_small.txt](test_dolphindb_small.txt) |
| 大数据集测试完整脚本 | [test_dolphindb_big.txt](test_dolphindb_big.txt)     |


-   InfluxDB

| 脚本                 | 文件                                               |
| -------------------- | -------------------------------------------------- |
| 安装、配置、测试脚本 | [test_influxdb.sh](test_influxdb.sh)               |
| InfluxDB 修改配置    | [influxdb.conf](influxdb.conf)                     |
| 小数据集测试完整脚本 | [test_influxdb_small.sql](test_influxdb_small.sql) |
| 大数据集测试完整脚本 | [test_influxdb_big.sql](test_influxdb_big.sql)     |

