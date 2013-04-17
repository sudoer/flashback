#!/usr/bin/python

volumeInfo = [
    { 'host':'aspire',  'name':'etc',     'src':'root@aspire:/etc/',     'cycleSec':86400*1,  },  # small
    { 'host':'aspire',  'name':'home',    'src':'root@aspire:/home/',    'cycleSec':86400*1,  },  # 46G
    { 'host':'aspire',  'name':'boot',    'src':'root@aspire:/boot/',    'cycleSec':86400*1,  },  # small
    { 'host':'bender',  'name':'root',    'src':'root@bender:/',         'cycleSec':86400*1,  },  # small
    { 'host':'bender',  'name':'boot',    'src':'root@bender:/boot/',    'cycleSec':86400*1,  },  # small
    { 'host':'bender',  'name':'home',    'src':'root@bender:/home/',    'cycleSec':86400*1,  },  # 13G
    { 'host':'bender',  'name':'backup',  'src':'root@bender:/backup/',  'cycleSec':86400*1,  },  # 44G
    { 'host':'bender',  'name':'pub',     'src':'root@bender:/pub/',     'cycleSec':86400*1,  },  # small
#   { 'host':'bender',  'name':'copy',    'src':'root@bender:/copy/',    'cycleSec':86400*2,  },  # 124G      evaluate
    { 'host':'enigma',  'name':'home',    'src':'root@enigma:/home/',    'cycleSec':86400*7,  },  # small
    { 'host':'digit',   'name':'users',   'src':'root@digit:/Users/',    'cycleSec':86400*1,  },  # 95G
#   { 'host':'digit',   'name':'x',       'src':'root@digit:/x/',        'cycleSec':86400*2,  },  # 203G      evaluate
    { 'host':'mini',    'name':'users',   'src':'root@mini:/Users/',     'cycleSec':86400*1,  },  # 2G
    { 'host':'sheeva',  'name':'root',    'src':'/',                     'cycleSec':86400*7,  },  # 2G
    { 'host':'sheeva',  'name':'boot',    'src':'/boot/',                'cycleSec':86400*7,  },  # small
    { 'host':'mirage',  'name':'home',    'src':'root@mirage:/home/',    'cycleSec':86400,    },  # 15G  ??
    { 'host':'xps',     'name':'home',    'src':'root@xps:/home/',       'cycleSec':86400*3,  },  # 35G
    { 'host':'xps',     'name':'etc',     'src':'root@xps:/etc/',        'cycleSec':86400*3,  },  # small
    { 'host':'xps',     'name':'boot',    'src':'root@xps:/boot/',       'cycleSec':86400*3,  },  # small
]

# XPS /dev/mapper/vg1-home         128G     35G     87G   29%  /home
# XPS /dev/mapper/vg1-vm           109G     62G     41G   61%  /mnt/vm
# XPS /dev/mapper/vg1-public        15G     11G    3.4G   77%  /mnt/public
# XPS /dev/mapper/vg1-tekelec       30G     24G    4.1G   86%  /mnt/tekelec
# XPS /dev/mapper/vg1-itunes        16G    6.7G    9.4G   42%  /mnt/itunes
# XPS /dev/mapper/vg1-music         50G     47G    3.0G   94%  /mnt/music
# XPS /dev/mapper/vg1-movies        50G     46G    3.6G   93%  /mnt/movies

