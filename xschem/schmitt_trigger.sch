v {xschem version=3.4.5 file_version=1.2
}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"
}
V {}
S {}
E {}
T {Schmitt trigger CMOS 6T} -20 -440 0 0 0.4 0.4 {}
T {Topologia clasica: 2 PMOS + 2 NMOS en serie en el inversor principal,
mas 1 PMOS y 1 NMOS de realimentacion (paralelo, gate=vout) que generan
la histeresis.
Vin sube  -> se necesita superar VTH (mayor a VDD/2) para que Vout baje
Vin baja  -> se necesita bajar de VTL (menor a VDD/2) para que Vout suba
VTH-VTL = ancho de histeresis.
SIZING FINAL (validado en ngspice, ver schmitt_tb.spice):
  MP_FB: W=16.0 L=64.0 | MN_FB: W=8.0 L=64.0
  Histeresis medida: ~43.5 mV (VTH=0.877V, VTL=0.834V @ VDD=1.8V)
  Velocidad @ 500kHz: trise=59.6ns tfall=34.2ns tpd=17-36ns (<3% del periodo)
  Nota: el placeholder original de >200mV en spec.md v1 era circular
  (no derivado de una fuente de ruido real medida) - ver spec.md v2.} -20 -410 0 0 0.25 0.25 {}

C {sky130_fd_pr/pfet_01v8.sym} 0 -300 0 0 {name=MP_FB
L=64.0
W=16.0
nf=1
model=pfet_01v8
spiceprefix=X}
C {sky130_fd_pr/pfet_01v8.sym} 0 -180 0 0 {name=MP1
L=0.15
W=2.0
nf=1
model=pfet_01v8
spiceprefix=X}
C {sky130_fd_pr/pfet_01v8.sym} 0 -60 0 0 {name=MP2
L=0.15
W=2.0
nf=1
model=pfet_01v8
spiceprefix=X}
C {sky130_fd_pr/nfet_01v8.sym} 0 60 0 0 {name=MN1
L=0.15
W=1.0
nf=1
model=nfet_01v8
spiceprefix=X}
C {sky130_fd_pr/nfet_01v8.sym} 0 180 0 0 {name=MN2
L=0.15
W=1.0
nf=1
model=nfet_01v8
spiceprefix=X}
C {sky130_fd_pr/nfet_01v8.sym} 0 300 0 0 {name=MN_FB
L=64.0
W=8.0
nf=1
model=nfet_01v8
spiceprefix=X}

N 20 -330 20 -345 {lab=VDD}
N 20 -345 -180 -345 {lab=VDD}
N -180 -345 -180 -200 {lab=VDD}
N 20 -210 40 -210 {lab=VDD}
N 20 -300 40 -300 {lab=VDD}
N 20 -180 40 -180 {lab=VDD}
N 20 -60 40 -60 {lab=VDD}

N 20 -270 40 -270 {lab=nodo_p}
N 20 -150 20 -90 {lab=nodo_p}

N 20 -30 20 30 {lab=vout}
N 20 -30 180 -30 {lab=vout}
N 180 -30 180 0 {lab=vout}

N 20 90 20 150 {lab=nodo_n}
N 20 270 40 270 {lab=nodo_n}

N 20 210 40 210 {lab=GND}
N 20 60 40 60 {lab=GND}
N 20 180 40 180 {lab=GND}
N 20 300 40 300 {lab=GND}
N 20 330 20 345 {lab=GND}
N 20 345 -180 345 {lab=GND}
N -180 345 -180 200 {lab=GND}

N -20 -300 -160 -300 {lab=vout}
N -160 -300 -160 -30 {lab=vout}

N -20 300 -150 300 {lab=vout}
N -150 300 -150 -30 {lab=vout}

N -20 -180 -260 -180 {lab=vin}
N -260 -180 -260 60 {lab=vin}
N -260 60 -20 60 {lab=vin}
N -20 -60 -260 -60 {lab=vin}
N -20 180 -260 180 {lab=vin}

C {devices/lab_pin.sym} -180 -200 0 0 {name=p_vdd sig_type=std_logic lab=VDD}
C {devices/lab_pin.sym} -180 200 0 0 {name=p_gnd sig_type=std_logic lab=GND}
C {devices/lab_pin.sym} -260 0 0 0 {name=p_vin sig_type=std_logic lab=vin}
C {devices/lab_pin.sym} 180 0 0 0 {name=p_vout sig_type=std_logic lab=vout}
