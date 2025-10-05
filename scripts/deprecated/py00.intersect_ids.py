import sys

if __name__ == "__main__":
    id_file1 = sys.argv[1]
    id_file2 = sys.argv[2]
    ids1 = set()
    ids2 = set()
    with open(id_file1) as f1:
        for line in f1:
            ids1.add(line.strip())
    with open(id_file2) as f2:
        for line in f2:
            ids2.add(line.strip())
    intersect_ids = ids1.intersection(ids2)
    for _id in sorted(intersect_ids):
        print(_id)