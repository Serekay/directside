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
from tkinter import ttk, filedialog
from pathlib import Path
from zipfile import ZipFile, BadZipFile

ROOT = Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parents[1]))
HOME = Path(sys.executable).parent if getattr(sys, 'frozen', False) else ROOT
BG, PANEL, FIELD, TEXT, MUTED, ACCENT = '#111418', '#1b2026', '#252c34', '#eef5f2', '#9ba9ad', '#35d3a6'

class Preferences:
    """Non-secret preferences only. Authentication remains in the OS keyring."""
    def __init__(self, path=None):
        self.path = Path(path) if path else Path(os.environ.get('LOCALAPPDATA', Path.home()/'AppData'/'Local'))/'DirectSide'/'preferences.json'

    def load(self):
        try:
            data = json.loads(self.path.read_text(encoding='utf-8'))
            return {key: data[key] for key in ('email', 'server') if isinstance(data.get(key), str)}
        except (OSError, ValueError, AttributeError):
            return {}

    def save(self, email, server):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.path.with_suffix('.tmp')
        temp.write_text(json.dumps({'email':email.strip(), 'server':server.strip()}, ensure_ascii=False), encoding='utf-8')
        temp.replace(self.path)

def valid_code(value):
    return len(value) == 6 and value.isascii() and value.isdigit()

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
        self.geometry('920x800')
        self.minsize(760, 690)
        self.configure(bg=BG)
        icon = ROOT / 'assets' / 'DirectSide.ico'
        if icon.exists(): self.iconbitmap(str(icon))
        self.events = queue.Queue()
        self.preferences = Preferences()
        saved = self.preferences.load()
        self.devices = []
        self.logged_in = False
        self.busy = False
        self.process = None
        self.initializing = True
        self.challenge_kind = None
        self.challenge_buttons = []
        self.email = tk.StringVar(value=saved.get('email', ''))
        self.password = tk.StringVar()
        self.device = tk.StringVar()
        self.ipa = tk.StringVar()
        self.server = tk.StringVar(value=saved.get('server', 'https://new.ani.sidestore.io'))
        self.status = tk.StringVar(value='Verbindung wird vorbereitet …')
        self.account_status = tk.StringVar(value='Mit deiner eigenen Apple-ID anmelden')
        self.setup_style()
        self.build_ui()
        self.set_busy(True)
        self.email_entry.bind('<FocusOut>', lambda _: self.save_preferences())
        for candidate in [HOME / 'DirectSide.ipa', ROOT / 'DirectSide.ipa', ROOT / 'dist' / 'DirectSide.ipa']:
            if candidate.is_file(): self.ipa.set(str(candidate)); break
        self.protocol('WM_DELETE_WINDOW', self.close)
        self.after(100, self.start_engine)
        self.after(100, self.poll)
        self.after(7000, self.auto_refresh)

    def setup_style(self):
        style = ttk.Style(self)
        style.theme_use('clam')
        style.configure('.', background=BG, foreground=TEXT, font=('Segoe UI', 10))
        style.configure('Panel.TFrame', background=PANEL)
        style.configure('Panel.TLabel', background=PANEL)
        style.configure('Panel.TCheckbutton', background=PANEL, foreground=MUTED)
        style.configure('Muted.TLabel', foreground=MUTED, background=PANEL)
        style.configure('TEntry', fieldbackground=FIELD, bordercolor='#354149', lightcolor=FIELD, darkcolor=FIELD, foreground=TEXT, padding=10)
        style.map('TEntry', bordercolor=[('focus',ACCENT)], foreground=[('disabled',MUTED)])
        style.configure('TCombobox', fieldbackground=FIELD, background=FIELD, bordercolor='#354149', lightcolor=FIELD, darkcolor=FIELD, foreground=TEXT, padding=9, arrowsize=15)
        style.map('TCombobox', fieldbackground=[('readonly', FIELD)], foreground=[('readonly', TEXT)])
        style.configure('TButton', background=FIELD, foreground=TEXT, padding=(15, 10), borderwidth=0)
        style.map('TButton', background=[('active', '#35434a')])
        style.configure('Primary.TButton', background=ACCENT, foreground='#073025', font=('Segoe UI', 11, 'bold'), padding=(18, 13))
        style.map('Primary.TButton', background=[('active', '#63e2bd'), ('disabled', '#315c50')], foreground=[('disabled', '#a6beb6')])
        style.configure('Horizontal.TProgressbar', troughcolor=BG, background=ACCENT, bordercolor=BG, lightcolor=BG, darkcolor=BG, borderwidth=0, thickness=4)

    def build_ui(self):
        top = tk.Frame(self, bg=BG, padx=28, pady=18)
        top.pack(fill='x')
        png = ROOT / 'assets' / 'brand-128.png'
        if png.exists():
            self.brand = tk.PhotoImage(master=self, file=str(png)).subsample(2)
            tk.Label(top, image=self.brand, bg=BG).pack(side='left', padx=(0, 14))
        title = tk.Frame(top, bg=BG)
        title.pack(side='left')
        tk.Label(title, text='DirectSide', bg=BG, fg=TEXT, font=('Segoe UI', 24, 'bold')).pack(anchor='w')
        tk.Label(title, text='Dein iPhone. Deine Apps. Einfach eingerichtet.', bg=BG, fg=MUTED, font=('Segoe UI', 10)).pack(anchor='w')
        ttk.Button(top, text='Einstellungen', command=self.settings).pack(side='right')
        self.notice = tk.Label(self, textvariable=self.status, bg='#17372f', fg=TEXT, font=('Segoe UI', 10), anchor='w', justify='left', padx=24, pady=13, wraplength=740)
        self.notice.pack(fill='x', padx=28, pady=(0, 12))
        self.bind('<Configure>', lambda e: self.notice.configure(wraplength=max(400, e.width-100)) if e.widget is self else None)
        self.progress = ttk.Progressbar(self, maximum=100)
        self.progress.pack(fill='x', padx=28, pady=(0, 8))
        steps=tk.Frame(self,bg=BG,padx=28,pady=8)
        steps.pack(fill='x')
        self.step_labels=[]
        for text in ['01  APPLE ACCOUNT','02  IPHONE VERBINDEN','03  INSTALLIEREN']:
            label=tk.Label(steps,text=text,bg=BG,fg=MUTED,font=('Segoe UI',9,'bold'),anchor='w')
            label.pack(side='left',expand=True,fill='x');self.step_labels.append(label)
        canvas = tk.Canvas(self, bg=BG, highlightthickness=0)
        self.canvas = canvas
        scrollbar = ttk.Scrollbar(self, orient='vertical', command=canvas.yview)
        scrollbar.pack(side='right', fill='y')
        canvas.pack(side='left', fill='both', expand=True)
        canvas.configure(yscrollcommand=scrollbar.set)
        outer = tk.Frame(canvas, bg=BG, padx=28, pady=10)
        content = canvas.create_window((0, 0), window=outer, anchor='nw')
        outer.bind('<Configure>', lambda _: canvas.configure(scrollregion=canvas.bbox('all')))
        canvas.bind('<Configure>', lambda event: canvas.itemconfigure(content, width=event.width))
        self.bind('<MouseWheel>', lambda event: canvas.yview_scroll(-int(event.delta / 120), 'units'))
        account = self.panel(outer, '1   Dein Apple Account')
        ttk.Label(account, textvariable=self.account_status, style='Muted.TLabel').grid(row=0, column=0, columnspan=2, sticky='w', pady=(0, 10))
        self.email_entry = ttk.Entry(account, textvariable=self.email)
        self.email_entry.grid(row=1, column=0, sticky='ew', padx=(0, 9))
        self.password_entry = ttk.Entry(account, textvariable=self.password, show='●')
        self.password_entry.grid(row=1, column=1, sticky='ew', padx=(0, 9))
        self.password_entry.bind('<Return>',lambda _: self.login() if not self.busy else None)
        self.email_entry.bind('<Return>',lambda _: self.password_entry.focus_set())
        self.login_button = ttk.Button(account, text='Anmelden', command=self.login)
        self.login_button.grid(row=1, column=2, sticky='ew')
        self.email_label=ttk.Label(account, text='Apple-ID', style='Muted.TLabel');self.email_label.grid(row=2, column=0, sticky='w', pady=(5, 0))
        self.password_label=ttk.Label(account, text='Apple-ID-Passwort', style='Muted.TLabel');self.password_label.grid(row=2, column=1, sticky='w', pady=(5, 0))
        self.account_hint=ttk.Label(account, text='Apple-ID wird auf diesem PC gemerkt. Deine Sitzung bleibt im Windows-Schlüsselbund.', style='Muted.TLabel', wraplength=660)
        self.account_hint.grid(row=3, column=0, columnspan=3, sticky='w', pady=(12, 0))
        self.challenge = tk.Frame(account, bg='#16392f', padx=16, pady=16)
        self.challenge.grid(row=4, column=0, columnspan=3, sticky='ew', pady=(14, 0))
        self.challenge.grid_remove()
        account.columnconfigure(0, weight=1); account.columnconfigure(1, weight=1)

        device = self.panel(outer, '2   Dein iPhone')
        self.device_box = ttk.Combobox(device, textvariable=self.device, state='readonly')
        self.device_box.grid(row=0, column=0, sticky='ew', padx=(0, 9))
        self.device_box.bind('<<ComboboxSelected>>', lambda _: self.update_controls())
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
        self.success = tk.Frame(outer, bg='#17372f', padx=18, pady=16)
        tk.Label(self.success, text='✓  DirectSide ist auf deinem iPhone', bg='#17372f', fg=ACCENT, font=('Segoe UI', 13, 'bold')).pack(anchor='w')
        tk.Label(self.success, text='1. Entwicklerprofil auf dem iPhone bestätigen und Entwicklermodus aktivieren.\n2. LocalDevVPN verbinden.\n3. DirectSide öffnen, anmelden und deine erste Quelle hinzufügen.', bg='#17372f', fg=TEXT, justify='left', wraplength=670).pack(anchor='w', pady=(10, 0))
        self.settings_panel = self.panel(outer, 'Verbindungseinstellungen')
        ttk.Label(self.settings_panel, text='Anisette-Server · HTTPS', style='Muted.TLabel').pack(anchor='w')
        ttk.Entry(self.settings_panel, textvariable=self.server).pack(fill='x', pady=(7, 10))
        ttk.Label(self.settings_panel, text='Die Anmelde-Header werden automatisch vom Server übernommen.', style='Muted.TLabel', wraplength=650).pack(anchor='w')
        ttk.Button(self.settings_panel, text='Speichern und schließen', command=self.save_settings).pack(anchor='e', pady=(12, 0))
        self.settings_panel.master.pack_forget()
        self.settings_visible = False
        self.details_button = ttk.Button(outer, text='Technische Details anzeigen / ausblenden', command=self.toggle_log)
        self.details_button.pack(anchor='w', pady=(8, 0))
        self.log = tk.Text(outer, height=4, bg=BG, fg=MUTED, font=('Consolas', 9), relief='flat', wrap='word', state='disabled')
        self.log_visible = False
        bottom = tk.Frame(outer, bg=BG)
        bottom.pack(fill='x', pady=(8, 0))
        tk.Label(bottom, text='3 App-Plätze · 7 Tage Signatur · Lokale Einrichtung mit deiner Apple-ID', bg=BG, fg=MUTED, font=('Segoe UI', 9), wraplength=650, justify='left').pack(side='left')
        self.ipa.trace_add('write', lambda *_: self.update_controls())

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
            self.show_error('Bitte Apple-ID und Passwort eingeben.'); return
        if not self.save_preferences(): return
        self.hide_challenge()
        self.notice.configure(bg='#17372f')
        self.account_status.set('Anmeldung bei Apple wird vorbereitet …')
        self.set_busy(True)
        self.send({'command':'login','email':self.email.get().strip(),'password':self.password.get(),'server':self.server.get().strip()})
        self.password.set('')

    def choose_ipa(self):
        path=filedialog.askopenfilename(parent=self, title='IPA auswählen', filetypes=[('iPhone-App','*.ipa')])
        if path: self.ipa.set(path)

    def install(self):
        if not self.logged_in:
            self.show_error('Bitte zuerst mit deiner Apple-ID anmelden.'); return
        idx=self.device_box.current()
        if idx<0 or idx>=len(self.devices):
            self.show_error('Bitte dein iPhone per USB verbinden und entsperren.'); return
        path=Path(self.ipa.get())
        try: bundle=ipa_identity(path)
        except (OSError, ValueError, BadZipFile, plistlib.InvalidFileException) as exc:
            self.show_error(f'Die IPA konnte nicht geprüft werden: {exc}'); return
        bootstrap=bundle=='com.directside.app'
        self.progress['value']=0
        self.success.pack_forget()
        self.notice.configure(bg='#17372f')
        self.command({'command':'install','device_id':self.devices[idx]['id'],'path':str(path.resolve()),'bootstrap':bootstrap,'bundle_id':bundle})

    def set_busy(self, value):
        self.busy=value
        if value:
            self.progress.pack(fill='x',padx=28,pady=(0,8),after=self.notice)
            if self.progress['value']==0:self.progress.configure(mode='indeterminate');self.progress.start(12)
        else:self.progress.stop();self.progress.configure(mode='determinate');self.progress.pack_forget()
        self.update_controls()

    def update_controls(self):
        value=self.busy
        state='disabled' if value else 'normal'
        for widget in [self.login_button,self.refresh_button,self.choose_button]: widget.configure(state=state)
        self.install_button.configure(state='normal' if not value and self.logged_in and self.devices and self.ipa.get() else 'disabled')
        self.email_entry.configure(state='disabled' if value or self.logged_in else 'normal')
        self.password_entry.configure(state='disabled' if value or self.logged_in else 'normal')
        self.device_box.configure(state='disabled' if value else 'readonly')
        self.step_labels[0].configure(fg=ACCENT if self.logged_in else TEXT)
        self.step_labels[1].configure(fg=ACCENT if self.devices else MUTED)
        self.step_labels[2].configure(fg=ACCENT if self.progress['value']==100 else TEXT if self.logged_in and self.devices else MUTED)

    def update_account(self):
        fields=[self.email_entry,self.password_entry,self.email_label,self.password_label]
        if self.logged_in:
            for field in fields:field.grid_remove()
            self.login_button.grid(row=0,column=2,sticky='e')
            self.account_hint.configure(text=(self.email.get()+' · ' if self.email.get() else '')+'Sitzung aktiv. DirectSide meldet dich beim nächsten Start automatisch an.')
        else:
            for field in fields:field.grid()
            self.login_button.grid(row=1,column=2,sticky='ew')
            self.account_hint.configure(text='Apple-ID wird auf diesem PC gemerkt. Deine Sitzung bleibt im Windows-Schlüsselbund.')

    def append_log(self, value):
        self.log.configure(state='normal'); self.log.insert('end',clean_error(value)+'\n'); self.log.see('end'); self.log.configure(state='disabled')

    def poll(self):
        while True:
            try: event=self.events.get_nowait()
            except queue.Empty: break
            self.handle_event(event)
        self.after(100,self.poll)

    def handle_event(self,event):
            kind=event.get('event')
            if kind=='ready':
                self.set_busy(True); self.status.set('Gespeicherte Anmeldung wird geprüft …'); self.send({'command':'restore'})
            elif kind=='devices':
                self.devices=event.get('devices',[])
                self.device_box['values']=[d['name'] for d in self.devices]
                if self.devices: self.device_box.current(0)
                else: self.device.set('Kein Gerät verbunden')
                if self.progress['value'] < 100 and self.notice.cget('bg') != '#493026':
                    self.status.set('iPhone verbunden. '+('Bereit zum Einrichten.' if self.logged_in else 'Bitte mit deiner Apple-ID anmelden.') if self.devices else 'iPhone per USB verbinden, entsperren und diesem PC vertrauen.')
                self.set_busy(False)
            elif kind=='logged_in':
                if event.get('email'):self.email.set(event['email']);self.save_preferences()
                self.hide_challenge(); self.logged_in=True; self.account_status.set('✓ Angemeldet · '+(event.get('team') or 'Dein Developer-Team')); self.login_button.configure(text='Abmelden'); self.set_busy(False)
                self.update_account()
                self.status.set('Angemeldet. Verbinde dein iPhone, um DirectSide einzurichten.')
                self.notice.configure(bg='#17372f')
                self.finish_initialization()
            elif kind=='logged_out':
                self.hide_challenge(); self.logged_in=False; self.account_status.set('Apple-ID gemerkt · Bitte Passwort eingeben' if self.email.get() else 'Mit deiner eigenen Apple-ID anmelden'); self.login_button.configure(text='Anmelden'); self.set_busy(False)
                self.update_account()
                self.finish_initialization()
            elif kind=='status': self.status.set(event.get('message','')); self.append_log(event.get('message',''))
            elif kind=='progress': self.progress.stop();self.progress.configure(mode='determinate');self.progress['value']=event.get('value',0)
            elif kind=='two_factor': self.two_factor(event)
            elif kind=='pairing_pin': self.pairing_pin()
            elif kind=='choose_team': self.select_team(event.get('teams',[]))
            elif kind=='installed':
                self.hide_challenge(); self.set_busy(False); self.progress['value']=100; self.update_controls();self.status.set('✓ Installation abgeschlossen. DirectSide ist bereit für den ersten Start auf dem iPhone.'); self.notice.configure(bg='#17372f'); self.success.pack(fill='x',before=self.details_button,pady=(5,12))
            elif kind=='error': self.show_error(event.get('message','Unbekannter Fehler'))
            elif kind=='diagnostic': self.append_log(event.get('message',''))
            elif kind=='engine_exit': self.hide_challenge(); self.set_busy(True); self.status.set('Signierkern beendet. Bitte DirectSide neu starten.'); self.notice.configure(bg='#493026')

    def finish_initialization(self):
        if self.initializing:
            self.initializing=False
            self.command({'command':'devices'})

    def auto_refresh(self):
        if not self.initializing and not self.busy and not self.challenge_kind and not self.devices and not self.password.get():
            self.command({'command':'devices'})
        self.after(7000,self.auto_refresh)

    def hide_challenge(self):
        self.challenge_kind=None
        self.challenge.grid_remove()
        for widget in self.challenge.winfo_children(): widget.destroy()
        self.challenge_buttons=[]

    def begin_challenge(self,kind,title,description):
        self.hide_challenge()
        self.challenge_kind=kind
        self.set_busy(True)
        self.challenge.grid()
        tk.Label(self.challenge,text=title,bg='#16392f',fg=TEXT,font=('Segoe UI',14,'bold')).pack(anchor='w')
        tk.Label(self.challenge,text=description,bg='#16392f',fg=TEXT,wraplength=630,justify='left').pack(anchor='w',pady=(8,12))
        self.challenge_hint=tk.StringVar()
        tk.Label(self.challenge,textvariable=self.challenge_hint,bg='#16392f',fg='#ffce97',wraplength=630,justify='left').pack(anchor='w',pady=(0,5))
        self.canvas.yview_moveto(0)
        self.notice.configure(bg='#17372f')
        self.status.set(title+' · Bitte direkt im Account-Bereich bestätigen.')

    def challenge_button(self,text,command,primary=False):
        button=ttk.Button(self.challenge,text=text,command=command,style='Primary.TButton' if primary else 'TButton')
        button.pack(fill='x',pady=(7,0));self.challenge_buttons.append(button)

    def answer_challenge(self,payload):
        if not self.challenge_kind:return
        self.hide_challenge()
        self.status.set('Bestätigung wird geprüft …')
        self.send(payload)

    def two_factor(self,event):
        self.begin_challenge('two_factor','Apple-Anmeldung bestätigen','Bestätige die Anmeldung auf deinem iPhone oder einem anderen vertrauenswürdigen Apple-Gerät. Gib anschließend den sechsstelligen Code hier ein.')
        if event.get('last_error'):self.challenge_hint.set('Apple hat den letzten Code nicht akzeptiert. Prüfe den Code oder fordere einen neuen an.')
        value=tk.StringVar();entry=ttk.Entry(self.challenge,textvariable=value,font=('Segoe UI',20),justify='center');entry.pack(fill='x',pady=(0,8));entry.focus_set()
        def submit():
            code=value.get().strip()
            if not valid_code(code):self.challenge_hint.set('Bitte genau sechs Ziffern eingeben.');entry.focus_set();return
            self.answer_challenge({'action':'code','code':code})
        entry.bind('<Return>',lambda _:submit())
        self.challenge_button('Code bestätigen',submit,True)
        self.challenge_button('Neuen Code an Apple-Geräte senden',lambda:self.answer_challenge({'action':'devices'}))
        for number in event.get('numbers',[]):
            self.challenge_button('SMS an '+str(number.get('numberWithDialCode','gespeicherte Nummer')),lambda n=number:self.answer_challenge({'action':'sms','number_id':n['id']}))
        self.challenge_button('Anmeldung abbrechen',lambda:self.answer_challenge({'action':'cancel'}))

    def pairing_pin(self):
        self.begin_challenge('pairing','iPhone-Verbindung bestätigen','Gib den Pairing-Code ein, den dein iPhone anzeigt. Lass das Gerät angeschlossen und entsperrt.')
        value=tk.StringVar();entry=ttk.Entry(self.challenge,textvariable=value,font=('Segoe UI',18));entry.pack(fill='x');entry.focus_set()
        self.challenge_button('Pairing bestätigen',lambda:self.answer_challenge({'code':value.get().strip()}),True)
        self.challenge_button('Abbrechen',lambda:self.answer_challenge({'code':''}))

    def select_team(self,teams):
        self.begin_challenge('team','Deinen Account auswählen','Wähle das Apple-Developer-Team für die Signierung deiner Apps.')
        for team in teams:
            self.challenge_button(team.get('name') or team['id'],lambda t=team:self.answer_challenge({'team_id':t['id']}),True)
        self.challenge_button('Abbrechen',lambda:self.answer_challenge({'team_id':''}))

    def settings(self):
        if self.busy:return
        self.settings_visible=not self.settings_visible
        if self.settings_visible:
            self.settings_panel.master.pack(fill='x',pady=(0,12))
            self.after_idle(lambda:self.canvas.yview_moveto(1))
        else:self.settings_panel.master.pack_forget()

    def save_settings(self):
        if not self.server.get().startswith('https://'):
            self.show_error('Bitte eine HTTPS-Adresse für den Anmeldeserver verwenden.');return
        if self.save_preferences():
            self.settings_visible=False;self.settings_panel.master.pack_forget();self.status.set('Verbindungseinstellungen gespeichert.')

    def save_preferences(self):
        try:self.preferences.save(self.email.get(),self.server.get());return True
        except OSError:
            self.status.set('Die Apple-ID konnte auf diesem PC nicht gespeichert werden. Bitte Schreibrechte im Benutzerprofil prüfen.');self.notice.configure(bg='#493026');return False

    def toggle_log(self):
        self.log_visible=not self.log_visible
        if self.log_visible:self.log.pack(fill='x',pady=(10,0));self.after_idle(lambda:self.canvas.yview_moveto(1))
        else:self.log.pack_forget()

    def show_error(self,message):
        self.hide_challenge();self.set_busy(False);self.status.set(clean_error(message));self.append_log(message);self.notice.configure(bg='#493026')

    def close(self):
        self.save_preferences()
        if self.process and self.process.poll() is None:
            try:self.process.terminate()
            except OSError:pass
        self.destroy()

if __name__=='__main__': DirectSide().mainloop()
