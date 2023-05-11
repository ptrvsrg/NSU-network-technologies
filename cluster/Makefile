check_DNS:
	nslookup fit.nsu 192.168.157.128
	nslookup fit2.nsu 192.168.157.128

check_node1_fit.nsu:
	printf 'GET / HTTP/1.1\r\nHost: fit.nsu\r\n\r\n' | nc 192.168.157.125 81

check_node1_fit2.nsu:
	printf 'GET / HTTP/1.1\r\nHost: fit2.nsu\r\n\r\n' | nc 192.168.157.125 81

check_node2_fit.nsu:
	printf 'GET / HTTP/1.1\r\nHost: fit.nsu\r\n\r\n' | nc 192.168.157.126 81

check_node2_fit2.nsu:
	printf 'GET / HTTP/1.1\r\nHost: fit2.nsu\r\n\r\n' | nc 192.168.157.126 81

check_proxy_fit.nsu:
	printf 'GET / HTTP/1.1\r\nHost: fit.nsu\r\n\r\n' | nc 192.168.157.11

check_proxy_fit2.nsu:
	printf 'GET / HTTP/1.1\r\nHost: fit2.nsu\r\n\r\n' | nc 192.168.157.11