import os, glob, json, configparser
apps = []
paths = ["/usr/share/applications/*.desktop", os.path.expanduser("~/.local/share/applications/*.desktop")]
seen = set()
for p in paths:
    for f in glob.glob(p):
        try:
            config = configparser.ConfigParser(interpolation=None)
            config.read(f)
            if 'Desktop Entry' in config:
                e = config['Desktop Entry']
                if e.get('NoDisplay', 'false').lower() == 'true': continue
                name = e.get('Name', '')
                icon = e.get('Icon', '')
                exec_cmd = e.get('Exec', '')
                id = os.path.basename(f)
                if name and exec_cmd and name not in seen:
                    exec_cmd = ' '.join(part for part in exec_cmd.split() if not part.startswith('%'))
                    apps.append({"name": name, "icon": icon, "exec": exec_cmd, "id": id})
                    seen.add(name)
        except Exception:
            pass
apps.sort(key=lambda x: x["name"].lower())
for a in apps:
    print(json.dumps(a))
