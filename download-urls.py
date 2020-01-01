from multiprocessing.dummy import Pool
from tqdm import tqdm
from urllib.parse import urlsplit
import urllib3
import itertools, functools, operator
import os
import sys
import re
import errno
import argparse

parser = argparse.ArgumentParser(description='Download a range or list of urls in parallel from a single domain.')
parser.add_argument('-n', '--n_connections', default=32, type=int, help='Number of parallel connections.')
parser.add_argument('-d', '--dry_run', action='store_true', help='Show the first few URLs to download.')
parser.add_argument('-z', '--zeropad', action='store_true', help='Pad zeros with maximum amount needed.')
parser.add_argument('-x', '--extension', default=None, type=str, help='Extension code, e.g. \'jpg\'.')

group = parser.add_mutually_exclusive_group(required=True)
group.add_argument('-l', '--list', default=sys.stdin, type=argparse.FileType('r'), help='File with a list of urls.')
group.add_argument('-u', '--urls', default='', type=str, help='URL with range(s) of numbers.')

args = parser.parse_args()

def ids_to_str(ids, stop):
    if args.zeropad:
        max_size = len(stop)
        return map(lambda e: str(e).zfill(max_size), ids)
    else:
        return map(str, ids)

domain = ''
urls = []
ids = []
job_count = 0
scheme = 'http'

if args.urls:
    parsed = urlsplit(args.urls)
    scheme = parsed.scheme
    domain = parsed.netloc
    path = parsed.path + ('?' + parsed.query if parsed.query else '')

    pieces = re.split('\[(.+?)\]', path)

    url_pieces = []
    id_pieces = []
    for i, piece in enumerate(pieces):
        if i % 2 == 0:
            url_pieces.append([piece])
        else:
            start, stop = piece.split('-')
            cur_id_pieces = range(int(start), int(stop)+1) # inclusive of end
            cur_url_pieces = ids_to_str(cur_id_pieces, stop)
            id_pieces.append(cur_id_pieces)
            url_pieces.append(cur_url_pieces)

    urls = map(lambda x: ''.join(x), itertools.product(*url_pieces))
    ids = itertools.product(*id_pieces)
    job_count = functools.reduce(operator.mul, map(len, id_pieces), 1)

else:
    full_urls = args.list.read().splitlines()
    for url in full_urls:
        parsed = urlsplit(url)
        path = parsed.path + ('?' + parsed.query if parsed.query else '')  
        pieces = [e for e in path.split('/') if e is not '']
        urls.append(path)
        ids.append(pieces)
    scheme = parsed.scheme
    domain = parsed.netloc
    job_count = len(urls)

if scheme == 'http':
    connection_pool = urllib3.HTTPConnectionPool(domain)
elif scheme == 'https':
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    connection_pool = urllib3.HTTPSConnectionPool(domain, cert_reqs='CERT_NONE')
else:
    print(f'Scheme not recognized: {scheme}')
    exit()

jobs = zip(urls, ids)

print('Accessing', job_count, 'URLs at', domain, 'across', args.n_connections, 'connections.')

def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise

def download(url, fn):
    if not os.path.isfile(fn):
        r = connection_pool.urlopen('GET', url)
        with open(fn, 'wb') as f:
            if r.status == 200:
                f.write(r.data)
            elif r.status != 404:
                print('Error {} requesting {}'.format(r.status, url))

def build_filename(ids):
    ids = list(map(str, ids))
    dir_name = os.path.join(domain, *ids[:-1])
    fn = os.path.join(dir_name, ids[-1] + ('.' + args.extension if args.extension else ''))
    return dir_name, fn

if args.dry_run:
    max_display = 10
    for url, ids in itertools.islice(jobs, max_display):
        dir_name, fn = build_filename(ids)
        print(f'{domain}{url} => {fn}')
    if job_count > max_display:
        print('... and {} more'.format(job_count - max_display))
else:
    pbar = tqdm(total=job_count, leave=True)
    def job(cur_job):
        url, ids = cur_job
        dir_name, fn = build_filename(ids)
        mkdir_p(dir_name)
        download(url, fn)
        pbar.update(1)

    pool = Pool(args.n_connections)
    pool.map(job, jobs)