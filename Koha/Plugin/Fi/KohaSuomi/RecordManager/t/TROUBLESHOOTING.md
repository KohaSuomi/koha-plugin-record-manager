# Troubleshooting: "No orphans found"

If the orphan detection endpoint returns no results, follow these steps:

## Common Errors

### Error: "Trying to create too many scroll contexts"

```
Trying to create too many scroll contexts. Must be less than or equal to: [500]
```

This happens when scroll contexts accumulate in Elasticsearch without being cleared.

**Quick Fix:**
```bash
cd Koha/Plugin/Fi/KohaSuomi/RecordManager/t/

# Clear all existing scroll contexts
./clear_es_scrolls.pl
```

**Root Cause:** The `host_record_exists` method was creating a scroll context for every component part checked. Fixed by using non-scrolling searches for single queries.

### Error: "DBIC result _type isn't of the _type BiblioMetadata"

This occurs when biblio records exist without proper metadata. This can happen with:
- Incorrectly imported records
- Database corruption
- Records created by external tools

**Fix:**
```bash
cd Koha/Plugin/Fi/KohaSuomi/RecordManager/t/

# Check for problematic records
./clean_problematic_records.pl

# Delete them (CAUTION: permanent!)
./clean_problematic_records.pl --delete
```

## Step 1: Check Setup

```bash
cd Koha/Plugin/Fi/KohaSuomi/RecordManager/t/
./check_setup.pl
```

This will check:
- ✓ Are there any records in the database?
- ✓ Is Elasticsearch configured?
- ✓ Is Elasticsearch running?
- ✓ Are records indexed?

## Step 2: Check Elasticsearch Data Structure

```bash
./check_es_structure.pl
```

This reveals:
- What fields actually exist in Elasticsearch
- What field names are used for MARC 773 data
- Sample records and their structure

**Common issues:**
- Field names don't match (e.g., `host-item-entry` vs `record-control-number-773w`)
- Records aren't indexed yet
- MARC mapping is different than expected

## Step 3: Create Test Data (if needed)

```bash
# Create host records and component parts
./populate_test_data.pl --hosts=10 --components=3 --orphans=5 --verbose

# Then rebuild the Elasticsearch index
perl rebuild_elasticsearch.pl -b -r -v
```

## Step 4: Fix Field Name Mismatches

If `check_es_structure.pl` shows different field names, update the search queries:

Edit `Koha/Plugin/Fi/KohaSuomi/RecordManager/Modules/Search.pm`:

```perl
# Find the actual field name from check_es_structure.pl output
# Then update the queries to use that field name

# Example: If actual field is 'host-item-entry' instead of 'record-control-number-773w'
# Change:
{ exists => { field => 'record-control-number-773w' } }
# To:
{ exists => { field => 'host-item-entry' } }
```

## Step 5: Check MARC Field Mapping

The Elasticsearch index uses a MARC-to-field mapping. Check your Koha's mapping file:

Common MARC 773 mappings:
- `773$w` → `host-item-entry`, `linked-host`, or `record-control-number-773w`
- `773$t` → `host-item-title`

## Quick Test Query

Test Elasticsearch directly:

```bash
# Replace with your values
ES_HOST="localhost:9200"
INDEX="koha_instance_biblios"

# Check total records
curl -s "http://$ES_HOST/$INDEX/_count" | jq .

# Find records with 773 field (try different field names)
curl -s "http://$ES_HOST/$INDEX/_search" -H 'Content-Type: application/json' -d '{
  "query": {
    "bool": {
      "should": [
        {"exists": {"field": "record-control-number-773w"}},
        {"exists": {"field": "host-item-entry"}},
        {"exists": {"field": "host-item"}},
        {"exists": {"field": "linked-host"}}
      ],
      "minimum_should_match": 1
    }
  },
  "size": 1
}' | jq .
```

## Expected Results

After fixing:
- Database should have component parts with MARC 773 field
- Elasticsearch should show these in the index with proper field names  
- Queries should match the actual field names
- Orphans (773$w pointing to non-existent hosts) should be detected
