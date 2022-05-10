import paramiko
import time

ip = input("ip address : ")
user = snocjb, pwd = cisco
print("Default Username = snocjb")
print("Default Password = cisco")
while 1:   
    time0 = time.time()

    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko. AutoAddPolicy())
        ssh.connect(ip, username=user, password=pwd)
    
    except Exception as err:
       print(err, "time =", time.time() - time0)
       ssh.close()
       continue

