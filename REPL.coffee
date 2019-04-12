run 'influxd.exe run -config influxdb.conf',
    cwd: 'D:/InfluxData/InfluxDB'
    title: 'InfluxDB.server'
    icon: 'server.ico'

run 'influxd.exe --help',
    cwd: 'D:/InfluxData/InfluxDB'
    title: 'InfluxDB.server'
    icon: 'server.ico'


run 'influx.exe -format column -precision rfc3339',
    cwd: 'D:/InfluxData/InfluxDB'
    title: 'InfluxDB.client'
    icon: 'client.ico'

run 'influx.exe -import -path=D:/1/comp/influxdb/readings_small.txt -precision=s -database=test',
    cwd: 'D:/InfluxData/InfluxDB'
    title: 'InfluxDB.client'
    icon: 'client.ico'

run 'influx.exe --help',
    cwd: 'D:/InfluxData/InfluxDB'
    title: 'InfluxDB.client'
    icon: 'client.ico'

run 'influx.exe --import',
    cwd: 'D:/InfluxData/InfluxDB'
    title: 'InfluxDB.client'
    icon: 'client.ico'


run 'telegraf.exe --config telegraf.conf --test',
    cwd: 'D:/InfluxData/Telegraf'
    title: 'Telegraf'

run 'telegraf.exe --config telegraf.conf',
    cwd: 'D:/InfluxData/Telegraf'
    title: 'Telegraf'


run 'chronograf.exe --help',
    cwd: 'D:/InfluxData/Chronograf'
    title: 'Chronograf'


run 'chronograf.exe',
    cwd: 'D:/InfluxData/Chronograf'
    title: 'Chronograf'



run 'go get github.com/influxdata/influxdb-comparisons/cmd/bulk_data_gen'
run 'go install github.com/influxdata/influxdb-comparisons/cmd/bulk_query_gen'
run 'go install github.com/influxdata/influxdb-comparisons/cmd/query_benchmarker_influxdb'


run 'bulk_data_gen.exe --help'
run 'bulk_query_gen.exe --help'
run 'bulk_load_influx.exe --help'
run 'query_benchmarker_influxdb.exe --help'

run 'bulk_query_gen.exe  -use-case devops  -query-type 1-host-1-hr  -format influx-http'




psh 'bulk_data_gen.exe -format influx-bulk  >  D:/InfluxDB/data.txt'
psh 'bulk_data_gen.exe -format timescaledb-sql  >  D:/timescaledb-sql.data.txt'
psh 'bulk_data_gen.exe -format timescaledb-copyFrom  >  D:/timescaledb-copyFrom.data.txt'
psh.run 'bulk_load_influx.exe  <  D:/InfluxDB/data.txt'

run 'go get github.com/influxdata/influxdb-comparisons/cmd/bulk_load_influx'

link 'E:/SDK/Go/mods/src/github.com/influxdata/influxdb-comparisons/', 'D:/InfluxDB/comp/'




child = call 'bulk_load_influx.exe',
    wait: false
    encoding: null

child.stderr.pipe process.stderr
child.stdout.pipe process.stdout


rs = fs.createReadStream('D:/InfluxDB/data.txt')

rs.pipe child.stdin


ws = fs.createWriteStream('D:/InfluxDB/query.dat')


child = call 'bulk_query_gen.exe  -use-case devops  -query-type 1-host-1-hr  -format influx-http',
    wait: false
    encoding: null
    stdio: ['ignore', ws, process.stdout]
    
    
ws.close()

ws.destroy()

rs = fs.createReadStream('D:/InfluxDB/query.dat', encoding: null)

child = call 'query_benchmarker_influxdb.exe',
    wait: false
    encoding: null

rs.pipe child.stdin

child.stdout.pipe process.stdout
child.stderr.pipe process.stdout

rs.close()

    
