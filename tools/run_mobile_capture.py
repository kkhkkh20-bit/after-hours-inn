import os,subprocess,socket,time,random,sys,shutil,tempfile
from pathlib import Path
project=Path(__file__).resolve().parent.parent
godot=os.environ.get("INN_GODOT_BIN") or shutil.which("godot") or "/tmp/sideview-bin/godot"
xvfb=os.environ.get("INN_XVFB_BIN") or shutil.which("Xvfb") or "/tmp/inn-assets/xroot/usr/bin/Xvfb"
n=random.randrange(250,850)
capture_data=tempfile.TemporaryDirectory(prefix='inn-capture-')
e=os.environ.copy();e['XDG_DATA_HOME']=capture_data.name;e['LD_LIBRARY_PATH']='/tmp/inn-assets/xroot/usr/lib/x86_64-linux-gnu';e['DISPLAY']='127.0.0.1:'+str(n)
with open('/tmp/mobile180-render.log','w') as log:
 x=subprocess.Popen([xvfb,':'+str(n),'-screen','0','900x1500x24','-ac','-nolisten','unix','-nolisten','local','-listen','tcp'],env=e,stdout=log,stderr=log)
 try:
  for i in range(50):
   try:
    with socket.create_connection(('127.0.0.1',6000+n),timeout=.1):break
   except OSError:time.sleep(.05)
  p=subprocess.run([godot,'--audio-driver','Dummy','--path',str(project),'--script','tools/capture_mobile.gd','--',*sys.argv[1:]],env=e,stdout=log,stderr=log,timeout=45)
  print('capture exit',p.returncode)
 finally:x.terminate();x.wait();capture_data.cleanup()
