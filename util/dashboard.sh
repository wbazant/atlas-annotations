
if [ $# -lt 2 ]; then
  echo "Usage: $0 annotationType taskFile"
  echo "e.g. $0 gsea /var/tmp/all-bsub-tasks"
  exit 1
fi

annotationType=$1
taskFile=$2

echo "Experiments redecorated: "
grep  -oe 'E-[[:upper:]]*-[[:digit:]]*' $taskFile | sort -u | wc -l
echo "Completed:"
grep  -oe 'E-[[:upper:]]*-[[:digit:]]*' $taskFile | sort -u | xargs -n1 bash -c "ls $ATLAS_PROD/analysis/*/*/experiments/\$1/$annotationType*.out 2>/dev/null" ^*^ | xargs grep -l "Successfully completed" | xargs -n1 dirname | xargs -n1 basename | sort -u | wc -l
echo "Failures:"
grep  -oe 'E-[[:upper:]]*-[[:digit:]]*' $taskFile | sort -u | xargs -n1 bash -c "ls $ATLAS_PROD/analysis/*/*/experiments/\$1/$annotationType*.out 2>/dev/null" ^*^ | xargs grep -l "Exited with" | sed 's/.out/.err/' | xargs grep ""
