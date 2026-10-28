using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.ComponentModel;

namespace WifiScope {
 public class Network {
  public string ssid, bssid, band, radio, security, encryption, adapter, adapterId;
  public int signal, dbm, channel, frequency, beacon; public int? width;
  public double maxRate; public bool connected; public string rssiSource="WLAN API";
 }
 public class Adapter { public string id,name,state; public double? receiveRate,transmitRate; public string bssid; }
 public class ScanResult { public List<Network> networks=new List<Network>(); public List<Adapter> adapters=new List<Adapter>(); public List<string> warnings=new List<string>(); public string error, scannedAt, source="windows-wlan-api"; public bool fresh; }
 public static class NativeWifi {
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct InterfaceInfo { public Guid id; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=256)] public string description; public int state; }
  [StructLayout(LayoutKind.Sequential)] struct Ssid { public uint length; [MarshalAs(UnmanagedType.ByValArray,SizeConst=32)] public byte[] bytes; }
  [StructLayout(LayoutKind.Sequential)] struct RateSet { public uint length; [MarshalAs(UnmanagedType.ByValArray,SizeConst=126)] public ushort[] rates; }
  [StructLayout(LayoutKind.Sequential)] struct Bss { public Ssid ssid; public uint phyId; [MarshalAs(UnmanagedType.ByValArray,SizeConst=6)] public byte[] mac; public int type,phy,rssi; public uint quality; public byte reg; public ushort beacon; public ulong timestamp,hostTimestamp; public ushort capability; public uint frequency; public RateSet rates; public uint ieOffset,ieSize; }
  [StructLayout(LayoutKind.Sequential)] struct Notification { public uint source,code; public Guid guid; public uint size; public IntPtr data; }
  [StructLayout(LayoutKind.Sequential)] struct Association { public Ssid ssid; public int type; [MarshalAs(UnmanagedType.ByValArray,SizeConst=6)] public byte[] mac; public int phy; public uint phyIndex,quality,rx,tx; }
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Connection { public int state,mode; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=256)] public string profile; public Association assoc; public int securityEnabled,oneX; public int auth,cipher; }
  delegate void Callback(ref Notification data,IntPtr context);
  [DllImport("wlanapi.dll")] static extern uint WlanOpenHandle(uint v,IntPtr r,out uint n,out IntPtr h);
  [DllImport("wlanapi.dll")] static extern uint WlanCloseHandle(IntPtr h,IntPtr r);
  [DllImport("wlanapi.dll")] static extern uint WlanEnumInterfaces(IntPtr h,IntPtr r,out IntPtr list);
  [DllImport("wlanapi.dll")] static extern void WlanFreeMemory(IntPtr p);
  [DllImport("wlanapi.dll")] static extern uint WlanScan(IntPtr h,ref Guid id,IntPtr ssid,IntPtr ie,IntPtr r);
  [DllImport("wlanapi.dll")] static extern uint WlanRegisterNotification(IntPtr h,uint source,bool ignore,Callback cb,IntPtr context,IntPtr r,out uint prev);
  [DllImport("wlanapi.dll")] static extern uint WlanGetNetworkBssList(IntPtr h,ref Guid id,IntPtr ssid,int type,bool security,IntPtr r,out IntPtr list);
  [DllImport("wlanapi.dll")] static extern uint WlanQueryInterface(IntPtr h,ref Guid id,int op,IntPtr r,out int size,out IntPtr data,out int valueType);
  static string Mac(byte[] v) { return BitConverter.ToString(v).Replace('-',':').ToLowerInvariant(); }
  static string Error(uint code) { return code==5 ? "Windows từ chối truy cập WLAN (Access denied / 5). Mở Start.cmd trực tiếp ngoài sandbox. Nếu vẫn lỗi, kiểm tra Settings > Privacy & security > Location và quyền ứng dụng desktop." : new Win32Exception((int)code).Message+" ("+code+")"; }
  public static int Channel(int f) { if(f==2484)return 14; if(f>=2412&&f<=2472)return (f-2407)/5; if(f==5935)return 2; if(f>=5955&&f<=7115)return (f-5950)/5; if(f>=5000&&f<5925)return (f-5000)/5; return 0; }
  static string Phy(int p) { string[] names={"Unknown","FHSS","DSSS","IR","802.11a","802.11b","802.11g","802.11n","802.11ac","802.11ad","802.11ax","802.11be"}; return p>=0&&p<names.Length?names[p]:"Unknown"; }
  static void Ies(Network n,byte[] data,bool privacy) {
   n.security=privacy?"Protected (unknown)":"Open"; n.encryption=privacy?"Unknown":"None";
   for(int i=0;i+2<=data.Length;) { int id=data[i++],len=data[i++]; if(i+len>data.Length)break;
    if(id==61&&len>=2) n.width=(data[i+1]&3)==0?20:40;
    if(id==192&&len>=3&&data[i]>0) { int w=data[i]; n.width=w==1?80:w==2?160:(int?)null; if(w==1&&data[i+2]!=0)n.width=Math.Abs(data[i+1]-data[i+2])==8?160:(int?)null; }
    if(id==48&&len>=8) { n.security="WPA2"; var auth=new List<string>(); var cipher=new List<string>(); int j=i+6; int pairs=data[j]|(data[j+1]<<8); j+=2;
     for(int k=0;k<pairs&&j+4<=i+len;k++,j+=4) { int t=data[j+3]; string s=t==4?"CCMP":t==8?"GCMP-128":t==9?"GCMP-256":t==2?"TKIP":"Cipher "+t; if(!cipher.Contains(s))cipher.Add(s); }
     if(j+2<=i+len){int count=data[j]|(data[j+1]<<8);j+=2;for(int k=0;k<count&&j+4<=i+len;k++,j+=4){int t=data[j+3];string s=t==8||t==9?"WPA3-SAE":t==18?"OWE":t==1||t==3||t==5?"WPA2-Enterprise":t==2||t==4||t==6?"WPA2-Personal":t==12||t==13?"WPA3-Enterprise":"AKM "+t;if(!auth.Contains(s))auth.Add(s);}}
     if(auth.Count>0)n.security=String.Join(" / ",auth.ToArray());if(cipher.Count>0)n.encryption=String.Join(" / ",cipher.ToArray());
    }
    if(id==221&&len>=4&&data[i]==0&&data[i+1]==80&&data[i+2]==242&&data[i+3]==1&&n.security=="Protected (unknown)")n.security="WPA";
    i+=len;
   }
   // HE/EHT channel width needs additional operation decoding. Never infer it from PHY alone.
   if(n.band=="6 GHz"||n.radio=="802.11be")n.width=null;
  }
  public static List<Adapter> Connections() {
   var adapters=new List<Adapter>();IntPtr h=IntPtr.Zero,list=IntPtr.Zero;uint v;uint status=WlanOpenHandle(2,IntPtr.Zero,out v,out h);if(status!=0)throw new Win32Exception((int)status);
   try{status=WlanEnumInterfaces(h,IntPtr.Zero,out list);if(status!=0)throw new Win32Exception((int)status);int count=Marshal.ReadInt32(list),size=Marshal.SizeOf(typeof(InterfaceInfo));for(int i=0;i<count;i++){var inf=(InterfaceInfo)Marshal.PtrToStructure(IntPtr.Add(list,8+i*size),typeof(InterfaceInfo));IntPtr cp=IntPtr.Zero;int cs,ct;status=WlanQueryInterface(h,ref inf.id,7,IntPtr.Zero,out cs,out cp,out ct);if(status!=0)continue;try{var cn=(Connection)Marshal.PtrToStructure(cp,typeof(Connection));adapters.Add(new Adapter{id=inf.id.ToString(),name=inf.description,state="Connected",bssid=Mac(cn.assoc.mac),receiveRate=cn.assoc.rx/1000.0,transmitRate=cn.assoc.tx/1000.0});}finally{WlanFreeMemory(cp);}}}finally{if(list!=IntPtr.Zero)WlanFreeMemory(list);WlanCloseHandle(h,IntPtr.Zero);}return adapters;
  }
  public static ScanResult Scan() {
   var result=new ScanResult(); IntPtr h=IntPtr.Zero,list=IntPtr.Zero; uint version; uint status=WlanOpenHandle(2,IntPtr.Zero,out version,out h);
   if(status!=0){result.error=Error(status);result.scannedAt=DateTime.UtcNow.ToString("o");return result;}
   try {
    status=WlanEnumInterfaces(h,IntPtr.Zero,out list); if(status!=0)throw new Win32Exception((int)status);
    int count=Marshal.ReadInt32(list),sz=Marshal.SizeOf(typeof(InterfaceInfo)); bool allFresh=count>0;
    for(int index=0;index<count;index++) {
     var inf=(InterfaceInfo)Marshal.PtrToStructure(IntPtr.Add(list,8+index*sz),typeof(InterfaceInfo)); var a=new Adapter {id=inf.id.ToString(),name=inf.description,state=inf.state==1?"Connected":inf.state==4?"Disconnected":"State "+inf.state};result.adapters.Add(a);
     IntPtr cp=IntPtr.Zero;int cs,ct; if(WlanQueryInterface(h,ref inf.id,7,IntPtr.Zero,out cs,out cp,out ct)==0){try{var cn=(Connection)Marshal.PtrToStructure(cp,typeof(Connection));a.bssid=Mac(cn.assoc.mac);a.receiveRate=cn.assoc.rx/1000.0;a.transmitRate=cn.assoc.tx/1000.0;}finally{WlanFreeMemory(cp);}}
     using(var done=new ManualResetEvent(false)) { bool fresh=false;Guid target=inf.id;Callback cb=delegate(ref Notification d,IntPtr ctx){if(d.guid==target&&d.source==8&&(d.code==7||d.code==8)){fresh=d.code==7;done.Set();}};uint prev;uint reg=WlanRegisterNotification(h,8,false,cb,IntPtr.Zero,IntPtr.Zero,out prev);uint sc=WlanScan(h,ref inf.id,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero);
      if(sc==0&&reg==0)done.WaitOne(4500); WlanRegisterNotification(h,0,false,null,IntPtr.Zero,IntPtr.Zero,out prev);GC.KeepAlive(cb);allFresh&=fresh;
      if(sc!=0)result.warnings.Add(a.name+": "+Error(sc));else if(!fresh)result.warnings.Add(a.name+": chưa nhận được xác nhận quét mới; kết quả có thể từ bộ nhớ đệm driver.");
     }
     IntPtr bssList=IntPtr.Zero;status=WlanGetNetworkBssList(h,ref inf.id,IntPtr.Zero,3,false,IntPtr.Zero,out bssList);
     if(status!=0){string warning=a.name+": "+Error(status);if(!result.warnings.Contains(warning))result.warnings.Add(warning);continue;}
     try { int total=Marshal.ReadInt32(bssList),n=Marshal.ReadInt32(bssList,4),entrySize=Marshal.SizeOf(typeof(Bss)); if(n<0||n>10000||8L+(long)n*entrySize>total)throw new Exception("Invalid WLAN buffer");
      for(int b=0;b<n;b++){int offset=8+b*entrySize;IntPtr ptr=IntPtr.Add(bssList,offset);var v=(Bss)Marshal.PtrToStructure(ptr,typeof(Bss));int mhz=(int)(v.frequency/1000);var net=new Network{ssid=Encoding.UTF8.GetString(v.ssid.bytes,0,(int)Math.Min(32,v.ssid.length)),bssid=Mac(v.mac),signal=(int)v.quality,dbm=v.rssi,frequency=mhz,channel=Channel(mhz),band=mhz<2500?"2.4 GHz":mhz>=5925&&mhz<=7125?"6 GHz":mhz<5925?"5 GHz":"Unknown",radio=Phy(v.phy),adapter=a.name,adapterId=a.id,beacon=v.beacon,width=null};net.connected=net.bssid==a.bssid;
       for(int r=0;r<Math.Min(126,v.rates.length);r++)net.maxRate=Math.Max(net.maxRate,(v.rates.rates[r]&0x7fff)*0.5);
       byte[] ies=new byte[0];if(v.ieSize<=2324&&v.ieOffset>=entrySize&&(long)offset+v.ieOffset+v.ieSize<=total){ies=new byte[v.ieSize];Marshal.Copy(IntPtr.Add(ptr,(int)v.ieOffset),ies,0,ies.Length);}Ies(net,ies,(v.capability&16)!=0);result.networks.Add(net);
      }
     } finally {WlanFreeMemory(bssList);}
    }
    result.fresh=allFresh;if(count==0)result.error="Không tìm thấy adapter Wi-Fi. Kết nối adapter và bật WLAN AutoConfig.";else if(result.networks.Count==0&&result.warnings.Count>0)result.error=String.Join("\n",result.warnings.ToArray());
   }catch(Exception e){result.error=e.Message;}finally{if(list!=IntPtr.Zero)WlanFreeMemory(list);WlanCloseHandle(h,IntPtr.Zero);}
   result.scannedAt=DateTime.UtcNow.ToString("o");return result;
  }
 }
}
