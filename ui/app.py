"""DirectSide's native Windows bootstrap application. Credentials travel over stdin only."""
from __future__ import annotations
import json
import os
import plistlib
import queue
import re
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from pathlib import Path
from zipfile import ZipFile, BadZipFile

ROOT = Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parents[1]))
HOME = Path(sys.executable).parent if getattr(sys, 'frozen', False) else ROOT
BG, PANEL, FIELD, TEXT, MUTED, ACCENT = '#111418', '#1b2026', '#252c34', '#eef5f2', '#9ba9ad', '#35d3a6'

def ipa_identity(path: Path) -> str:
    with ZipFile(path) as archive:
        files = [n for n in archive.namelist() if n.startswith('Payload/') and n.count('/') == 2 and n.endswith('.app/Info.plist')]
        if len(files) != 1:
            raise ValueError('Die IPA enthält keine eindeutige Haupt-App.')
        info = archive.getinfo(files[0])
        if info.file_size > 2_000_000:
            raise ValueError('Die App-Metadaten sind ungewöhnlich groß.')
        return str(plistlib.loads(archive.read(files[0])).get('CFBundleIdentifier', ''))

def clean_error(value: str) -> str:
    value = re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[Apple-ID]', value)
    return value[:4000]

class DirectSide(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('DirectSide · iPhone einrichten')
        self.geometry('850x740')
        self.minsize(760, 690)
        self.configure(bg=BG)
        icon = ROOT / 'assets' / 'DirectSide.ico'
        if icon.exists(): self.iconbitmap(str(icon))
        self.events = queue.Queue()
        self.devices = []
        self.logged_in = False
        self.busy = False
        self.process = None
        self.email = tk.StringVar()
        self.password = tk.StringVar()
        self.device = tk.StringVar()
        self.ipa = tk.StringVar()
        self.server = tk.StringVar(value='https://new.ani.sidestore.io')
        self.status = tk.StringVar(value='Verbindung wird vorbereitet …')
        self.account_status = tk.StringVar(value='Mit deiner eigenen Apple-ID anmelden')
        self.setup_style()
        self.build_ui()
        for candidate in [HOME / 'DirectSide.ipa', ROOT / 'DirectSide.ipa', ROOT / 'dist' / 'DirectSide.ipa']:
            if candidate.is_file(): self.ipa.set(str(candidate)); break
        self.protocol('WM_DELETE_WINDOW', self.close)
        self.after(100, self.start_engine)
        self.after(100, self.poll)

    def setup_style(self):
        style = ttk.Style(self)
        style.theme_use('clam')
        style.configure('.', background=BG, foreground=TEXT, font=('Segoe UI', 10))
        style.configure('Panel.TFrame', background=PANEL)
        style.configure('Panel.TLabel', background=PANEL)
        style.configure('Muted.TLabel', foreground=MUTED, background=PANEL)
        style.configure('TEntry', fieldbackground=FIELD, bordercolor=FIELD, foreground=TEXT, padding=10)
        style.configure('TCombobox', fieldbackground=FIELD, background=FIELD, foreground=TEXT, padding=9, arrowsize=15)
        style.map('TCombobox', fieldbackground=[('readonly', FIELD)], foreground=[('readonly', TEXT)])
        style.configure('TButton', background=FIELD, foreground=TEXT, padding=(15, 10), borderwidth=0)
        style.map('TButton', background=[('active', '#35434a')])
        style.configure('Primary.TButton', background=ACCENT, foreground='#073025', font=('Segoe UI', 11, 'bold'), padding=(18, 13))
        style.map('Primary.TButton', background=[('active', '#63e2bd'), ('disabled', '#315c50')], foreground=[('disabled', '#a6beb6')])
        style.configure('Horizontal.TProgressbar', troughcolor=FIELD, background=ACCENT, borderwidth=0, thickness=5)

    def build_ui(self):
        outer = tk.Frame(self, bg=BG)
        outer.pack(fill='both', expand=True, padx=32, pady=27)
        header = tk.Frame(outer, bg=BG)
        header.pack(fill='x', pady=(0, 19))
        png = ROOT / 'assets' / 'brand-128.png'
        if png.exists():
            self.brand = tk.PhotoImage(file=str(png)).subsample(2)
            tk.Label(header, image=self.brand, bg=BG).pack(side='left', padx=(0, 15))
        headings = tk.Frame(header, bg=BG)
        headings.pack(side='left')
        tk.Label(headings, text='DirectSide', bg=BG, fg=TEXT, font=('Segoe UI', 26, 'bold')).pack(anchor='w')
        tk.Label(headings, text='Einmal einrichten. Danach direkt auf deinem iPhone.', bg=BG, fg=MUTED, font=('Segoe UI', 10)).pack(anchor='w', pady=(3, 0))

        account = self.panel(outer, '1   Dein Apple Account')
        ttk.Label(account, textvariable=self.account_status, style='Muted.TLabel').grid(row=0, column=0, columnspan=3, sticky='w', pady=(0, 10))
        self.email_entry = ttk.Entry(account, textvariable=self.email)
        self.email_entry.grid(row=1, column=0, sticky='ew', padx=(0, 9))
        self.password_entry = ttk.Entry(account, textvariable=self.password, show='●')
        self.password_entry.grid(row=1, column=1, sticky='ew', padx=(0, 9))
        self.login_button = ttk.Button(account, text='Anmelden', command=self.login)
        self.login_button.grid(row=1, column=2, sticky='ew')
        ttk.Label(account, text='Apple-ID', style='Muted.TLabel').grid(row=2, column=0, sticky='w', pady=(5, 0))
        ttk.Label(account, text='Apple-ID-Passwort', style='Muted.TLabel').grid(row=2, column=1, sticky='w', pady=(5, 0))
        account.columnconfigure(0, weight=1); account.columnconfigure(1, weight=1)

        device = self.panel(outer, '2   Dein iPhone')
        self.device_box = ttk.Combobox(device, textvariable=self.device, state='readonly')
        self.device_box.grid(row=0, column=0, sticky='ew', padx=(0, 9))
        self.refresh_button = ttk.Button(device, text='Aktualisieren', command=lambda: self.command({'command': 'devices'}))
        self.refresh_button.grid(row=0, column=1)
        ttk.Label(device, text='Per USB verbinden, entsperren und dem Computer vertrauen.', style='Muted.TLabel').grid(row=1, column=0, columnspan=2, sticky='w', pady=(9, 0))
        device.columnconfigure(0, weight=1)

        package = self.panel(outer, '3   DirectSide installieren')
        ttk.Entry(package, textvariable=self.ipa).grid(row=0, column=0, sticky='ew', padx=(0, 9))
        self.choose_button = ttk.Button(package, text='IPA auswählen', command=self.choose_ipa)
        self.choose_button.grid(row=0, column=1)
        ttk.Label(package, text='Die Original-IPA und das Pairing werden automatisch in DirectSide eingerichtet.', style='Muted.TLabel', wraplength=650).grid(row=1, column=0, columnspan=2, sticky='w', pady=(10, 12))
        self.install_button = ttk.Button(package, text='DirectSide auf dem iPhone einrichten', style='Primary.TButton', command=self.install)
        self.install_button.grid(row=2, column=0, columnspan=2, sticky='ew')
        package.columnconfigure(0, weight=1)
        ttk.Progressbar(outer, maximum=100, variable=None).pack_forget()
        self.progress = ttk.Progressbar(outer, maximum=100)
        self.progress.pack(fill='x', pady=(10, 12))
        ttk.Label(outer, textvariable=self.status, wraplength=740).pack(anchor='w')
        self.log = tk.Text(outer, height=4, bg=BG, fg=MUTED, font=('Consolas', 9), relief='flat', wrap='word', state='disabled')
        self.log.pack(fill='both', expand=True, pady=(11, 0))
        bottom = tk.Frame(outer, bg=BG)
        bottom.pack(fill='x', pady=(8, 0))
        tk.Label(bottom, text='Dein Passwort wird nicht gespeichert. Apple-Signierfristen gelten weiterhin.', bg=BG, fg=MUTED, font=('Segoe UI', 9)).pack(side='left')
        ttk.Button(bottom, text='Verbindung', command=self.settings).pack(side='right')

    def panel(self, outer, title):
        shell = tk.Frame(outer, bg=PANEL)
        shell.pack(fill='x', pady=(0, 12))
        tk.Label(shell, text=title, bg=PANEL, fg=TEXT, font=('Segoe UI', 12, 'bold')).pack(anchor='w', padx=18, pady=(14, 10))
        content = ttk.Frame(shell, style='Panel.TFrame')
        content.pack(fill='x', padx=18, pady=(0, 16))
        return content

    def start_engine(self):
        candidates = [ROOT/'bin'/'directside-engine.exe', ROOT/'target'/'x86_64-pc-windows-gnullvm'/'release'/'directside-engine.exe']
        engine = next((p for p in candidates if p.is_file()), None)
        if engine is None:
            self.show_error('Der Signierkern fehlt neben der Anwendung. Bitte das vollständige Paket verwenden.'); return
        try:
            self.process = subprocess.Popen([str(engine)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8', creationflags=subprocess.CREATE_NO_WINDOW)
        except OSError as exc:
            self.show_error(str(exc)); return
        threading.Thread(target=self.read_events, daemon=True).start()
        threading.Thread(target=self.read_stderr, daemon=True).start()

    def read_events(self):
        for line in self.process.stdout:
            try: self.events.put(json.loads(line))
            except json.JSONDecodeError: pass
        self.events.put({'event':'engine_exit'})

    def read_stderr(self):
        for line in self.process.stderr:
            self.events.put({'event':'diagnostic','message':clean_error(line.strip())})

    def send(self, payload):
        if not self.process or self.process.poll() is not None:
            self.show_error('Der Signierkern läuft nicht. Bitte DirectSide neu starten.'); return
        try:
            self.process.stdin.write(json.dumps(payload, ensure_ascii=False)+'\n'); self.process.stdin.flush()
        except (OSError, BrokenPipeError): self.show_error('Die Verbindung zum Signierkern wurde beendet.')

    def command(self, payload):
        if self.busy: return
        self.set_busy(True)
        self.send(payload)

    def login(self):
        if self.logged_in:
            self.send({'command':'logout'}); return
        if not self.email.get().strip() or not self.password.get():
            messagebox.showinfo('Apple-ID', 'Bitte Apple-ID und Passwort eingeben.', parent=self); return
        self.set_busy(True)
        self.send({'command':'login','email':self.email.get().strip(),'password':self.password.get(),'server':self.server.get().strip()})
        self.password.set('')

    def choose_ipa(self):
        path=filedialog.askopenfilename(parent=self, title='IPA auswählen', filetypes=[('iPhone-App','*.ipa')])
        if path: self.ipa.set(path)

    def install(self):
        if not self.logged_in:
            messagebox.showinfo('Apple-ID', 'Bitte zuerst anmelden.', parent=self); return
        idx=self.device_box.current()
        if idx<0 or idx>=len(self.devices):
            messagebox.showinfo('iPhone', 'Bitte dein verbundenes Gerät auswählen.', parent=self); return
        path=Path(self.ipa.get())
        try: bundle=ipa_identity(path)
        except (OSError, ValueError, BadZipFile, plistlib.InvalidFileException) as exc:
            self.show_error(f'Die IPA konnte nicht geprüft werden: {exc}'); return
        bootstrap=bundle=='com.directside.app'
        self.progress['value']=0
        self.command({'command':'install','device_id':self.devices[idx]['id'],'path':str(path.resolve()),'bootstrap':bootstrap,'bundle_id':bundle})

    def set_busy(self, value):
        self.busy=value
        state='disabled' if value else 'normal'
        for widget in [self.login_button,self.refresh_button,self.choose_button,self.install_button]: widget.configure(state=state)
        self.email_entry.configure(state='disabled' if value or self.logged_in else 'normal')
        self.password_entry.configure(state='disabled' if value or self.logged_in else 'normal')
        self.device_box.configure(state='disabled' if value else 'readonly')

    def append_log(self, value):
        self.log.configure(state='normal'); self.log.insert('end',clean_error(value)+'\n'); self.log.see('end'); self.log.configure(state='disabled')

    def poll(self):
        while True:
            try: event=self.events.get_nowait()
            except queue.Empty: break
            kind=event.get('event')
            if kind=='ready': self.send({'command':'restore'}); self.send({'command':'devices'})
            elif kind=='devices':
                self.devices=event.get('devices',[])
                self.device_box['values']=[d['name'] for d in self.devices]
                if self.devices: self.device_box.current(0)
                else: self.device.set('Kein Gerät verbunden')
                self.status.set('Gerät bereit.' if self.devices else 'iPhone verbinden und entsperren.')
                self.set_busy(False)
            elif kind=='logged_in':
                self.logged_in=True; self.account_status.set('Verbunden · '+(event.get('team') or 'Dein Developer-Team')); self.login_button.configure(text='Abmelden'); self.set_busy(False)
            elif kind=='logged_out':
                self.logged_in=False; self.account_status.set('Mit deiner eigenen Apple-ID anmelden'); self.login_button.configure(text='Anmelden'); self.set_busy(False)
            elif kind=='status': self.status.set(event.get('message','')); self.append_log(event.get('message',''))
            elif kind=='progress': self.progress['value']=event.get('value',0)
            elif kind=='two_factor': self.two_factor(event)
            elif kind=='pairing_pin': self.pairing_pin()
            elif kind=='choose_team': self.select_team(event.get('teams',[]))
            elif kind=='installed':
                self.set_busy(False); self.progress['value']=100; self.status.set('Installation abgeschlossen. Du kannst DirectSide auf dem iPhone öffnen.'); messagebox.showinfo('DirectSide bereit','Die App wurde installiert. Beim ersten Start gegebenenfalls deinem Entwicklerprofil vertrauen und LocalDevVPN verbinden.',parent=self)
            elif kind=='error': self.show_error(event.get('message','Unbekannter Fehler'))
            elif kind=='diagnostic': self.append_log(event.get('message',''))
            elif kind=='engine_exit': self.set_busy(False); self.status.set('Signierkern beendet. Bitte die Anwendung neu starten.')
        self.after(100,self.poll)

    def dialog(self, title, description):
        win=tk.Toplevel(self);win.title(title);win.configure(bg=PANEL);win.geometry('440x350');win.transient(self);win.grab_set()
        tk.Label(win,text=title,bg=PANEL,fg=TEXT,font=('Segoe UI',17,'bold')).pack(anchor='w',padx=22,pady=(22,10))
        tk.Label(win,text=description,bg=PANEL,fg=MUTED,wraplength=390,justify='left',font=('Segoe UI',10)).pack(anchor='w',padx=22,pady=(0,15))
        return win

    def two_factor(self,event):
        win=self.dialog('Apple-Bestätigung','Bestätige die Anmeldung auf einem vertrauenswürdigen Apple-Gerät und gib den sechsstelligen Code hier ein.')
        value=tk.StringVar();entry=ttk.Entry(win,textvariable=value);entry.pack(fill='x',padx=22,pady=(0,12));entry.focus_set()
        def respond(data): self.send(data);win.destroy()
        def submit():
            code=value.get().strip()
            if len(code)!=6 or not code.isascii() or not code.isdigit(): messagebox.showinfo('Code','Bitte sechs Ziffern eingeben.',parent=win);return
            respond({'action':'code','code':code})
        ttk.Button(win,text='Code bestätigen',style='Primary.TButton',command=submit).pack(fill='x',padx=22,pady=(0,7))
        ttk.Button(win,text='An vertrauenswürdige Geräte senden',command=lambda:respond({'action':'devices'})).pack(fill='x',padx=22,pady=(0,7))
        for number in event.get('numbers',[])[:1]:
            ttk.Button(win,text='SMS an '+str(number.get('numberWithDialCode','gespeicherte Nummer')),command=lambda n=number:respond({'action':'sms','number_id':n['id']})).pack(fill='x',padx=22,pady=(0,7))
        win.protocol('WM_DELETE_WINDOW',lambda:respond({'action':'cancel'}))

    def pairing_pin(self):
        win=self.dialog('iPhone-Pairing','Falls das iPhone einen Pairing-Code anzeigt, gib ihn hier ein.')
        value=tk.StringVar();ttk.Entry(win,textvariable=value).pack(fill='x',padx=22)
        def done():self.send({'code':value.get().strip()});win.destroy()
        ttk.Button(win,text='Bestätigen',command=done).pack(fill='x',padx=22,pady=15)
        win.protocol('WM_DELETE_WINDOW',lambda:(self.send({'code':''}),win.destroy()))

    def select_team(self,teams):
        win=self.dialog('Developer-Team','Wähle den Account, mit dem du deine Apps signieren möchtest.')
        for team in teams:
            def choose(t=team): self.send({'team_id':t['id']});win.destroy()
            ttk.Button(win,text=team.get('name') or team['id'],command=choose).pack(fill='x',padx=22,pady=5)
        win.protocol('WM_DELETE_WINDOW',lambda:(self.send({'team_id':''}),win.destroy()))

    def settings(self):
        if self.busy:return
        win=self.dialog('Anmeldeverbindung','DirectSide übernimmt die erforderlichen Anisette-Header automatisch vom gewählten HTTPS-Server.')
        ttk.Entry(win,textvariable=self.server).pack(fill='x',padx=22,pady=10)
        ttk.Button(win,text='Fertig',command=win.destroy).pack(fill='x',padx=22)

    def show_error(self,message):
        self.set_busy(False);self.status.set('Vorgang fehlgeschlagen.');self.append_log(message)
        messagebox.showerror('DirectSide',clean_error(message),parent=self)

    def close(self):
        if self.process and self.process.poll() is None:
            try:self.process.terminate()
            except OSError:pass
        self.destroy()

if __name__=='__main__': DirectSide().mainloop()
