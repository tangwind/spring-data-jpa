/*
 * Copyright 2011-2023 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

grammar Hql;

@header {
/**
 * HQL per https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#query-language
 *
 * This is a mixture of Hibernate's BNF and missing bits of grammar. There are gaps and inconsistencies in the
 * BNF itself, explained by other fragments of their spec. Additionally, alternate labels are used to provide easier
 * management of complex rules in the generated Visitor. Finally, there are labels applied to rule elements (op=('+'|'-')
 * to simplify the processing.
 *
 * @author Greg Turnquist
 * @author Mark Paluch
 * @author Yannick Brandt
 * @since 3.1
 */
}

/*
    Parser rules
 */

start
    : ql_statement EOF
    ;

ql_statement
    : selectStatement
    | updateStatement
    | deleteStatement
    | insertStatement
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-select
selectStatement
    : queryExpression
    ;

queryExpression
    : withClause? orderedQuery (setOperator orderedQuery)*
    ;

withClause
    : WITH cte (',' cte)*
    ;

cte
    : identifier AS (NOT? MATERIALIZED)? '(' queryExpression ')' searchClause? cycleClause?
    ;

searchClause
    : SEARCH (BREADTH | DEPTH) FIRST BY searchSpecifications SET identifier
    ;

searchSpecifications
    : searchSpecification (',' searchSpecification)*
    ;

searchSpecification
    : identifier sortDirection? nullsPrecedence?
    ;

cycleClause
    : CYCLE cteAttributes SET identifier (TO literal DEFAULT literal)? (USING identifier)?
    ;

cteAttributes
    : identifier (',' identifier)*
    ;

orderedQuery
    : (query | '(' queryExpression ')') queryOrder?  limitClause? offsetClause? fetchClause?
    ;

query
    : selectClause fromClause? whereClause? groupByClause? havingClause? # SelectQuery
    | fromClause whereClause? groupByClause? havingClause? selectClause? # FromQuery
    ;

queryOrder
    : orderByClause
    ;

fromClause
    : FROM entityWithJoins (',' entityWithJoins)*
    ;

entityWithJoins
    : fromRoot (joinSpecifier)*
    ;

joinSpecifier
    : join
    | crossJoin
    | jpaCollectionJoin
    ;

fromRoot
    : entityName variable?                         # RootEntity
    | LATERAL? '(' subquery ')' variable?          # RootSubquery
    | setReturningFunction variable?               # RootFunction
    ;

join
    : joinType JOIN FETCH? joinTarget joinRestriction? // Spec BNF says joinType isn't optional, but text says that it is.
    ;

joinTarget
    : path variable?                                # JoinPath
    | LATERAL? '(' subquery ')' variable?           # JoinSubquery
    | LATERAL? setReturningFunction variable?       # JoinFunctionCall
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-update
updateStatement
    : UPDATE VERSIONED? targetEntity setClause whereClause?
    ;

targetEntity
    : entityName variable?
    ;

setClause
    : SET assignment (',' assignment)*
    ;

assignment
    : simplePath '=' expressionOrPredicate
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-delete
deleteStatement
    : DELETE FROM? targetEntity whereClause?
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-insert
insertStatement
    : INSERT INTO? targetEntity targetFields (queryExpression | valuesList) conflictClause?
    ;

// Already defined underneath updateStatement
//targetEntity
//    : entityName variable?
//    ;

targetFields
    : '(' simplePath (',' simplePath)* ')'
    ;

valuesList
    : VALUES values (',' values)*
    ;

values
    : '(' expression (',' expression)* ')'
    ;

/**
 * a 'conflict' clause in an 'insert' statement
 */
conflictClause
    : ON CONFLICT conflictTarget? DO conflictAction
    ;

conflictTarget
    : ON CONSTRAINT identifier
    | '(' simplePath (',' simplePath)* ')'
    ;

conflictAction
    : NOTHING
    | UPDATE setClause whereClause?
    ;

instantiation
    : NEW instantiationTarget '(' instantiationArguments ')'
    ;

groupedItem
    : identifier
    | INTEGER_LITERAL
    | expression
    ;

sortedItem
    : sortExpression sortDirection? nullsPrecedence?
    ;

sortExpression
    : identifier
    | INTEGER_LITERAL
    | expression
    ;

sortDirection
    : ASC
    | DESC
    ;

nullsPrecedence
    : NULLS (FIRST | LAST)
    ;

limitClause
    : LIMIT parameterOrIntegerLiteral
    ;

offsetClause
    : OFFSET parameterOrIntegerLiteral (ROW | ROWS)?
    ;

fetchClause
    : FETCH (FIRST | NEXT) (parameterOrIntegerLiteral | parameterOrNumberLiteral '%') (ROW | ROWS) (ONLY | WITH TIES)
    ;

/*******************
    Gaps in the spec.
 *******************/

subquery
    : queryExpression
    ;

selectClause
    : SELECT DISTINCT? selectionList
    ;

selectionList
    : selection (',' selection)*
    ;

selection
    : selectExpression variable?
    ;

selectExpression
    : instantiation
    | mapEntrySelection
    | jpaSelectObjectSyntax
    | expressionOrPredicate
    ;

mapEntrySelection
    : ENTRY '(' path ')'
    ;

/**
 * Deprecated syntax dating back to EJB-QL prior to EJB 3, required by JPA, never documented in Hibernate
 */
jpaSelectObjectSyntax
    : OBJECT '(' identifier ')'
    ;

whereClause
    : WHERE predicate (',' predicate)*
    ;

joinType
    : INNER?
    | (LEFT | RIGHT | FULL)? OUTER?
    | CROSS
    ;

crossJoin
    : CROSS JOIN entityName variable?
    ;

joinRestriction
    : (ON | WITH) predicate
    ;

// Deprecated syntax dating back to EJB-QL prior to EJB 3, required by JPA, never documented in Hibernate
jpaCollectionJoin
    : ',' IN '(' path ')' variable?
    ;

groupByClause
    : GROUP BY groupedItem (',' groupedItem)*
    ;

orderByClause
    : ORDER BY sortedItem (',' sortedItem)*
    ;

havingClause
    : HAVING predicate (',' predicate)*
    ;

setOperator
    : UNION ALL?
    | INTERSECT ALL?
    | EXCEPT ALL?
    ;

// Literals
// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-literals
literal
    : STRING_LITERAL
    | JAVA_STRING_LITERAL
    | NULL
    | booleanLiteral
    | numericLiteral
    | binaryLiteral
    | temporalLiteral
    | arrayLiteral
    | generalizedLiteral
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-boolean-literals
booleanLiteral
    : TRUE
    | FALSE
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-numeric-literals
numericLiteral
    : INTEGER_LITERAL
    | LONG_LITERAL
    | BIG_INTEGER_LITERAL
    | FLOAT_LITERAL
    | DOUBLE_LITERAL
    | BIG_DECIMAL_LITERAL
    | HEX_LITERAL
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-datetime-literals
/**
 * A literal datetime, in braces, or with the 'datetime' keyword
 */
dateTimeLiteral
    : localDateTimeLiteral
    | zonedDateTimeLiteral
    | offsetDateTimeLiteral
    ;

localDateTimeLiteral
    : '(' localDateTime ')'
    | LOCAL? DATETIME localDateTime
    ;

zonedDateTimeLiteral
    : '(' zonedDateTime ')'
    | ZONED? DATETIME zonedDateTime
    ;

offsetDateTimeLiteral
    : '(' offsetDateTime ')'
    | OFFSET? DATETIME offsetDateTimeWithMinutes
    ;
/**
 * A literal date, in braces, or with the 'date' keyword
 */
dateLiteral
    : '(' date ')'
    | LOCAL? DATE date
    ;

/**
 * A literal time, in braces, or with the 'time' keyword
 */
timeLiteral
    : '(' time ')'
    | LOCAL? TIME time
    ;

/**
 * A literal datetime
 */
 dateTime
     : localDateTime
     | zonedDateTime
     | offsetDateTime
     ;

localDateTime
    : date time
    ;

zonedDateTime
    : date time zoneId
    ;

offsetDateTime
    : date time offset
    ;

offsetDateTimeWithMinutes
    : date time offsetWithMinutes
    ;

/**
 * A JDBC-style timestamp escape, as required by JPQL
 */
jdbcTimestampLiteral
    : TIMESTAMP_ESCAPE_START (dateTime | genericTemporalLiteralText) '}'
    ;

/**
 * A JDBC-style date escape, as required by JPQL
 */
jdbcDateLiteral
    : DATE_ESCAPE_START (date | genericTemporalLiteralText) '}'
    ;

/**
 * A JDBC-style time escape, as required by JPQL
 */
jdbcTimeLiteral
    : TIME_ESCAPE_START (time | genericTemporalLiteralText) '}'
    ;

genericTemporalLiteralText
    : STRING_LITERAL
    ;

/**
 * A generic format for specifying literal values of arbitary types
 */
arrayLiteral
    : '[' (expression (',' expression)*)? ']'
    ;

/**
 * A generic format for specifying literal values of arbitary types
 */
generalizedLiteral
    : '(' generalizedLiteralType ':' generalizedLiteralText ')'
    ;

generalizedLiteralType : STRING_LITERAL;
generalizedLiteralText : STRING_LITERAL;

/**
 * A literal date
 */
date
    : year '-' month '-' day
    ;

/**
 * A literal time
 */
time
    : hour ':' minute (':' second)?
    ;

/**
 * A literal offset
 */
offset
    : (PLUS | MINUS) hour (':' minute)?
    ;

offsetWithMinutes
    : (PLUS | MINUS) hour ':' minute
    ;

year: INTEGER_LITERAL;
month: INTEGER_LITERAL;
day: INTEGER_LITERAL;
hour: INTEGER_LITERAL;
minute: INTEGER_LITERAL;
second: INTEGER_LITERAL | DOUBLE_LITERAL;
zoneId
    : IDENTIFIER ('/' IDENTIFIER)?
    | STRING_LITERAL;

/**
 * A field that may be extracted from a date, time, or datetime
 */
extractField
    : datetimeField
    | dayField
    | weekField
    | timeZoneField
    | dateOrTimeField
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-duration-literals
datetimeField
    : YEAR
    | MONTH
    | DAY
    | WEEK
    | QUARTER
    | HOUR
    | MINUTE
    | SECOND
    | NANOSECOND
    | EPOCH
    ;

dayField
    : DAY OF MONTH
    | DAY OF WEEK
    | DAY OF YEAR
    ;

weekField
    : WEEK OF MONTH
    | WEEK OF YEAR
    ;

timeZoneField
    : OFFSET (HOUR | MINUTE)?
    | TIMEZONE_HOUR | TIMEZONE_MINUTE
    ;

dateOrTimeField
    : DATE
    | TIME
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-binary-literals
binaryLiteral
    : BINARY_LITERAL
    | '{' HEX_LITERAL (',' HEX_LITERAL)*  '}'
    ;

/**
 * A literal date, time, or datetime, in HQL syntax, or as a JDBC-style "escape" syntax
 */
temporalLiteral
    : dateTimeLiteral
    | dateLiteral
    | timeLiteral
    | jdbcTimestampLiteral
    | jdbcDateLiteral
    | jdbcTimeLiteral
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-java-constants
// TBD

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-entity-name-literals
// TBD

// Expressions
// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-expressions
// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-concatenation
// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-numeric-arithmetic
expression
    : '(' expression ')'                                            # GroupedExpression
    | '(' expressionOrPredicate (',' expressionOrPredicate)+ ')'    # TupleExpression
    | '(' subquery ')'                                              # SubqueryExpression
    | primaryExpression                                             # PlainPrimaryExpression
    | op=('+' | '-') numericLiteral                                 # SignedNumericLiteral
    | op=('+' | '-') expression                                     # SignedExpression
    | expression datetimeField                                      # ToDurationExpression
    | expression BY datetimeField                                   # FromDurationExpression
    | expression op=('*' | '/') expression                          # MultiplicationExpression
    | expression op=('+' | '-') expression                          # AdditionExpression
    | expression '||' expression                                    # HqlConcatenationExpression
    | DAY OF WEEK                                                   # DayOfWeekExpression
    | DAY OF MONTH                                                  # DayOfMonthExpression
    | WEEK OF YEAR                                                  # WeekOfYearExpression
    ;

primaryExpression
    : caseList                                                      # CaseExpression
    | literal                                                       # LiteralExpression
    | parameter                                                     # ParameterExpression
    | entityTypeReference                                           # EntityTypeExpression
    | entityIdReference                                             # EntityIdExpression
    | entityVersionReference                                        # EntityVersionExpression
    | entityNaturalIdReference                                      # EntityNaturalIdExpression
    | syntacticDomainPath pathContinuation?                         # SyntacticPathExpression
    | function                                                      # FunctionExpression
    | generalPathFragment                                           # GeneralPathExpression
    ;

/**
 * A much more complicated path expression involving operators and functions
 *
 * A path which needs to be resolved semantically.  This recognizes
 * any path-like structure.  Generally, the path is semantically
 * interpreted by the consumer of the parse-tree.  However, there
 * are certain cases where we can syntactically recognize a navigable
 * path; see 'syntacticNavigablePath' rule
 */
path
    : syntacticDomainPath pathContinuation?
    | generalPathFragment
    ;

generalPathFragment
    : simplePath indexedPathAccessFragment?
    ;

indexedPathAccessFragment
    : '[' expression ']' ('.' generalPathFragment)?
    ;

/**
 * A simple path expression
 *
 * - a reference to an identification variable (not case-sensitive),
 * - followed by a list of period-separated identifiers (case-sensitive)
 */
simplePath
    : identifier simplePathElement*
    ;

/**
 * An element of a simple path expression: a period, and an identifier (case-sensitive)
 */
simplePathElement
    : '.' identifier
    ;

/**
 * A continuation of a path expression "broken" by an operator or function
 */
pathContinuation
    : '.' simplePath
    ;

/**
 * The special function 'type()'
 */
entityTypeReference
    : TYPE '(' (path | parameter) ')'
    ;

/**
 * The special function 'id()'
 */
entityIdReference
    : ID '(' path ')' pathContinuation?
    ;

/**
 * The special function 'version()'
 */
entityVersionReference
    : VERSION '(' path ')'
    ;

/**
 * The special function 'naturalid()'
 */
entityNaturalIdReference
    : NATURALID '(' path ')' pathContinuation?
    ;

/**
 * An operator or function that may occur within a path expression
 *
 * Rule for cases where we syntactically know that the path is a
 * "domain path" because it is one of these special cases:
 *
 *         * TREAT( path )
 *         * ELEMENTS( path )
 *         * INDICES( path )
 *         * VALUE( path )
 *         * KEY( path )
 *         * path[ selector ]
 *         * ARRAY_GET( embeddableArrayPath, index ).path
 *         * COALESCE( array1, array2 )[ selector ].path
 */
syntacticDomainPath
    : treatedNavigablePath
    | collectionValueNavigablePath
    | mapKeyNavigablePath
    | simplePath indexedPathAccessFragment
    | simplePath slicedPathAccessFragment
    | toOneFkReference
    | function pathContinuation
    | function indexedPathAccessFragment pathContinuation?
    | function slicedPathAccessFragment
    ;

/**
 * The slice operator to obtain elements between the lower and upper bound.
 */
slicedPathAccessFragment
    : '[' expression ':' expression ']'
    ;

/**
 * A 'treat()' function that "breaks" a path expression
 */
treatedNavigablePath
    : TREAT '(' path AS simplePath ')' pathContinuation?
    ;

/**
 * A 'value()' function that "breaks" a path expression
 */
collectionValueNavigablePath
    : elementValueQuantifier '(' path ')' pathContinuation?
    ;

/**
 * A 'key()' or 'index()' function that "breaks" a path expression
 */
mapKeyNavigablePath
    : indexKeyQuantifier '(' path ')' pathContinuation?
    ;

/**
 * The special function 'fk()'
 */
toOneFkReference
    : FK '(' path ')'
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-case-expressions
caseList
    : simpleCaseExpression
    | searchedCaseExpression
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-simple-case-expressions
simpleCaseExpression
    : CASE expressionOrPredicate caseWhenExpressionClause+ (ELSE expressionOrPredicate)? END
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-searched-case-expressions
searchedCaseExpression
    : CASE caseWhenPredicateClause+ (ELSE expressionOrPredicate)? END
    ;

caseWhenExpressionClause
    : WHEN expression THEN expressionOrPredicate
    ;

caseWhenPredicateClause
    : WHEN predicate THEN expressionOrPredicate
    ;

// Functions
/**
 * A function invocation that may occur in an arbitrary expression
 */
function
    : standardFunction                           # StandardFunctionInvocation
    | aggregateFunction                          # AggregateFunctionInvocation
    | collectionSizeFunction                     # CollectionSizeFunctionInvocation
    | collectionAggregateFunction                # CollectionAggregateFunctionInvocation
    | collectionFunctionMisuse                   # CollectionFunctionMisuseInvocation
    | jpaNonstandardFunction                     # JpaNonstandardFunctionInvocation
    | columnFunction                             # ColumnFunctionInvocation
    | jsonFunction                               # JsonFunctionInvocation
    | xmlFunction                                # XmlFunctionInvocation
    | genericFunction                            # GenericFunctionInvocation
    ;

setReturningFunction
    : simpleSetReturningFunction
    | jsonTableFunction
    | xmlTableFunction
    ;

simpleSetReturningFunction
    : identifier '(' genericFunctionArguments? ')'
    ;

/**
 * Any function with an irregular syntax for the argument list
 *
 * These are all inspired by the syntax of ANSI SQL
 */
standardFunction
    : castFunction
    | treatedNavigablePath
    | extractFunction
    | truncFunction
    | formatFunction
    | collateFunction
    | substringFunction
    | overlayFunction
    | trimFunction
    | padFunction
    | positionFunction
    | currentDateFunction
    | currentTimeFunction
    | currentTimestampFunction
    | instantFunction
    | localDateFunction
    | localTimeFunction
    | localDateTimeFunction
    | offsetDateTimeFunction
    | cube
    | rollup
    ;

/**
 * The 'cast()' function for typecasting
 */
castFunction
    : CAST '(' expression AS castTarget ')'
    ;

/**
 * The target type for a typecast: a typename, together with length or precision/scale
 */
castTarget
    : castTargetType ('(' INTEGER_LITERAL (',' INTEGER_LITERAL)? ')')?
    ;

/**
 * The name of the target type in a typecast
 *
 * Like the 'entityName' rule, we have a specialized dotIdentifierSequence rule
 */
castTargetType
    returns [String fullTargetName]
    : (i=identifier { $fullTargetName = _localctx.i.getText(); }) ('.' c=identifier { $fullTargetName += ("." + _localctx.c.getText() ); })*
    ;

/**
 * The two formats for the 'substring() function: one defined by JPQL, the other by ANSI SQL
 */
substringFunction
    : SUBSTRING '(' expression ',' substringFunctionStartArgument (',' substringFunctionLengthArgument)? ')'
    | SUBSTRING '(' expression FROM substringFunctionStartArgument (FOR substringFunctionLengthArgument)? ')'
    ;

substringFunctionStartArgument
    : expression
    ;

substringFunctionLengthArgument
    : expression
    ;

/**
 * The ANSI SQL-style 'trim()' function
 */
trimFunction
    : TRIM '(' trimSpecification? trimCharacter? FROM? expression ')'
    ;

trimSpecification
    : LEADING
    | TRAILING
    | BOTH
    ;

trimCharacter
    : STRING_LITERAL
    | parameter
    ;

/**
 * A 'pad()' function inspired by 'trim()'
 */
padFunction
    : PAD '(' expression WITH padLength padSpecification padCharacter? ')'
    ;

padSpecification
    : LEADING
    | TRAILING
    ;

padCharacter
    : STRING_LITERAL
    ;

padLength
    : expression
    ;

/**
 * The ANSI SQL-style 'position()' function
 */
positionFunction
    : POSITION '(' positionFunctionPatternArgument IN positionFunctionStringArgument ')'
    ;

positionFunctionPatternArgument
    : expression
    ;

positionFunctionStringArgument
    : expression
    ;

/**
 * The ANSI SQL-style 'overlay()' function
 */
overlayFunction
    : OVERLAY '(' overlayFunctionStringArgument PLACING overlayFunctionReplacementArgument FROM overlayFunctionStartArgument (FOR overlayFunctionLengthArgument)? ')'
    ;

overlayFunctionStringArgument
    : expression
    ;

overlayFunctionReplacementArgument
    : expression
    ;

overlayFunctionStartArgument
    : expression
    ;

overlayFunctionLengthArgument
    : expression
    ;

/**
 * The deprecated current_date function required by JPQL
 */
currentDateFunction
    : CURRENT_DATE ('(' ')')?
    | CURRENT DATE
    ;

/**
 * The deprecated current_time function required by JPQL
 */
currentTimeFunction
    : CURRENT_TIME ('(' ')')?
    | CURRENT TIME
    ;

/**
 * The deprecated current_timestamp function required by JPQL
 */
currentTimestampFunction
    : CURRENT_TIMESTAMP ('(' ')')?
    | CURRENT TIMESTAMP
    ;

/**
 * The instant function, and deprecated current_instant function
 */
instantFunction
    : CURRENT_INSTANT ('(' ')')? //deprecated legacy syntax
    | INSTANT
    ;

/**
 * The 'local datetime' function (or literal if you prefer)
 */
localDateTimeFunction
    : LOCAL_DATETIME ('(' ')')?
    | LOCAL DATETIME
    ;

/**
 * The 'offset datetime' function (or literal if you prefer)
 */
offsetDateTimeFunction
    : OFFSET_DATETIME ('(' ')')?
    | OFFSET DATETIME
    ;

/**
 * The 'local date' function (or literal if you prefer)
 */
localDateFunction
    : LOCAL_DATE ('(' ')')?
    | LOCAL DATE
    ;

/**
 * The 'local time' function (or literal if you prefer)
 */
localTimeFunction
    : LOCAL_TIME ('(' ')')?
    | LOCAL TIME
    ;

/**
 * The 'format()' function for formatting dates and times according to a pattern
 */
formatFunction
    : FORMAT '(' expression AS format ')'
    ;

/**
 * The name of a database-defined collation
 *
 * Certain databases allow a period in a collation name
 */
collation
    : simplePath
    ;

/**
 * The special 'collate()' functions
 */
collateFunction
    : COLLATE '(' expression AS collation ')'
    ;

/**
 * The 'cube()' function specific to the 'group by' clause
 */
cube
    : CUBE '(' expressionOrPredicate (',' expressionOrPredicate)* ')'
    ;

/**
 * The 'rollup()' function specific to the 'group by' clause
 */
rollup
    : ROLLUP '(' expressionOrPredicate (',' expressionOrPredicate)* ')'
    ;

/**
 * A format pattern, with a syntax inspired by by java.time.format.DateTimeFormatter
 *
 * see 'Dialect.appendDatetimeFormat()'
 */
format
    : STRING_LITERAL
    ;

/**
 * The 'extract()' function for extracting fields of dates, times, and datetimes
 */
extractFunction
    : EXTRACT '(' extractField FROM expression ')'
    | datetimeField '(' expression ')'
    ;

/**
 * The 'trunc()' function for truncating both numeric and datetime values
 */
truncFunction
    : (TRUNC | TRUNCATE) '(' expression (',' (datetimeField | expression))? ')'
    ;

/**
 * A syntax for calling user-defined or native database functions, required by JPQL
 */
jpaNonstandardFunction
    : FUNCTION '(' jpaNonstandardFunctionName (AS castTarget)? (',' genericFunctionArguments)? ')'
    ;

/**
 * The name of a user-defined or native database function, given as a quoted string
 */
jpaNonstandardFunctionName
    : STRING_LITERAL
    | identifier
    ;

columnFunction
    : COLUMN '(' path '.' jpaNonstandardFunctionName (AS castTarget)? ')'
    ;

/**
 * Any function invocation that follows the regular syntax
 *
 * The function name, followed by a parenthesized list of ','-separated expressions
 */
genericFunction
    : genericFunctionName '(' (genericFunctionArguments | ASTERISK)? ')' pathContinuation?
      nthSideClause? nullsClause? withinGroupClause? filterClause? overClause?
    ;

/**
 * The name of a generic function, which may contain periods and quoted identifiers
 *
 * Names of generic functions are resolved against the SqmFunctionRegistry
 */
genericFunctionName
    : simplePath
    ;

/**
 * The arguments of a generic function
 */
genericFunctionArguments
    : (DISTINCT | datetimeField ',')? expressionOrPredicate (',' expressionOrPredicate)*
    ;

/**
 * The special 'size()' function defined by JPQL
 */
collectionSizeFunction
    : SIZE '(' path ')'
    ;

/**
 * Special rule for 'max(elements())`, 'avg(keys())', 'sum(indices())`, etc., as defined by HQL
 * Also the deprecated 'maxindex()', 'maxelement()', 'minindex()', 'minelement()' functions from old HQL
 */
collectionAggregateFunction
    : (MAX|MIN|SUM|AVG) '(' elementsValuesQuantifier '(' path ')' ')'    # ElementAggregateFunction
    | (MAX|MIN|SUM|AVG) '(' indicesKeysQuantifier '(' path ')' ')'    # IndexAggregateFunction
    | (MAXELEMENT|MINELEMENT) '(' path ')'                                            # ElementAggregateFunction
    | (MAXINDEX|MININDEX) '(' path ')'                                                # IndexAggregateFunction
    ;

/**
 * To accommodate the misuse of elements() and indices() in the select clause
 *
 * (At some stage in the history of HQL, someone mixed them up with value() and index(),
 *  and so we have tests that insist they're interchangeable. Ugh.)
 */
collectionFunctionMisuse
    : elementsValuesQuantifier '(' path ')'
    | indicesKeysQuantifier '(' path ')'
    ;

/**
 * The special 'every()', 'all()', 'any()' and 'some()' functions defined by HQL
 *
 * May be applied to a subquery or collection reference, or may occur as an aggregate function in the 'select' clause
 */
aggregateFunction
    : everyFunction
    | anyFunction
    | listaggFunction
    ;

/**
 * The functions 'every()' and 'all()' are synonyms
 */
everyFunction
    : everyAllQuantifier '(' predicate ')' filterClause? overClause?
    | everyAllQuantifier '(' subquery ')'
    | everyAllQuantifier collectionQuantifier '(' simplePath ')'
    ;

/**
 * The functions 'any()' and 'some()' are synonyms
 */
anyFunction
    : anySomeQuantifier '(' predicate ')' filterClause? overClause?
    | anySomeQuantifier '(' subquery ')'
    | anySomeQuantifier collectionQuantifier '(' simplePath ')'
    ;

everyAllQuantifier
    : EVERY
    | ALL
    ;

anySomeQuantifier
    : ANY
    | SOME
    ;

/**
 * The 'listagg()' ordered set-aggregate function
 */
listaggFunction
    : LISTAGG '(' DISTINCT? expressionOrPredicate ',' expressionOrPredicate onOverflowClause? ')'
      withinGroupClause? filterClause? overClause?
    ;

/**
 * A 'on overflow' clause: what to do when the text data type used for 'listagg' overflows
 */
onOverflowClause
    : ON OVERFLOW (ERROR | TRUNCATE expression? (WITH|WITHOUT) COUNT)
    ;

/**
 * A 'within group' clause: defines the order in which the ordered set-aggregate function should work
 */
withinGroupClause
    : WITHIN GROUP '(' orderByClause ')'
    ;

/**
 * A 'filter' clause: a restriction applied to an aggregate function
 */
filterClause
    : FILTER '(' whereClause ')'
    ;

/**
 * A `nulls` clause: what should a value access window function do when encountering a `null`
 */
nullsClause
    : RESPECT NULLS
    | IGNORE NULLS
    ;

/**
 * A `nulls` clause: what should a value access window function do when encountering a `null`
 */
nthSideClause
    : FROM FIRST
    | FROM LAST
    ;

/**
 * A 'over' clause: the specification of a window within which the function should act
 */
overClause
    : OVER '(' partitionClause? orderByClause? frameClause? ')'
    ;

/**
 * A 'partition' clause: the specification the group within which a function should act in a window
 */
partitionClause
    : PARTITION BY expression (',' expression)*
    ;

/**
 * A 'frame' clause: the specification the content of the window
 */
frameClause
    : (RANGE|ROWS|GROUPS) frameStart frameExclusion?
    | (RANGE|ROWS|GROUPS) BETWEEN frameStart AND frameEnd frameExclusion?
    ;

/**
 * The start of the window content
 */
frameStart
    : CURRENT ROW
    | UNBOUNDED PRECEDING
    | expression PRECEDING
    | expression FOLLOWING
    ;

/**
 * The end of the window content
 */
frameEnd
    : CURRENT ROW
    | UNBOUNDED FOLLOWING
    | expression PRECEDING
    | expression FOLLOWING
    ;

/**
 * A 'exclusion' clause: the specification what to exclude from the window content
 */
frameExclusion
    : EXCLUDE CURRENT ROW
    | EXCLUDE GROUP
    | EXCLUDE TIES
    | EXCLUDE NO OTHERS
    ;

// JSON Functions

jsonFunction
    : jsonArrayFunction
    | jsonExistsFunction
    | jsonObjectFunction
    | jsonQueryFunction
    | jsonValueFunction
    | jsonArrayAggFunction
    | jsonObjectAggFunction
    ;

/**
 * The 'json_array(… ABSENT ON NULL)' function
 */
jsonArrayFunction
    : JSON_ARRAY '(' (expressionOrPredicate (',' expressionOrPredicate)* jsonNullClause?)? ')';

/**
 * The 'json_exists(, PASSING … AS … WITH WRAPPER ERROR|NULL|DEFAULT on ERROR|EMPTY)' function
 */
jsonExistsFunction
    : JSON_EXISTS '(' expression ',' expression jsonPassingClause? jsonExistsOnErrorClause? ')';

jsonExistsOnErrorClause
    : (ERROR | TRUE | FALSE) ON ERROR
    ;

/**
 * The 'json_object( foo, bar, KEY foo VALUE bar, foo:bar ABSENT ON NULL)' function
 */
jsonObjectFunction
    : JSON_OBJECT '(' jsonObjectFunctionEntry? (',' jsonObjectFunctionEntry)* jsonNullClause? ')';

jsonObjectFunctionEntry
    : (expressionOrPredicate|jsonObjectKeyValueEntry|jsonObjectAssignmentEntry);

jsonObjectKeyValueEntry
    : KEY? expressionOrPredicate VALUE expressionOrPredicate;

jsonObjectAssignmentEntry
    : expressionOrPredicate ':' expressionOrPredicate;

/**
 * The 'json_query(, PASSING … AS … WITH WRAPPER ERROR|NULL|DEFAULT on ERROR|EMPTY)' function
 */
jsonQueryFunction
    : JSON_QUERY '(' expression ',' expression jsonPassingClause? jsonQueryWrapperClause? jsonQueryOnErrorOrEmptyClause? jsonQueryOnErrorOrEmptyClause? ')';

jsonQueryWrapperClause
    : WITH (CONDITIONAL | UNCONDITIONAL)? ARRAY? WRAPPER
    | WITHOUT ARRAY? WRAPPER
    ;

jsonQueryOnErrorOrEmptyClause
    : (ERROR | NULL | EMPTY (ARRAY | OBJECT)?) ON (ERROR | EMPTY);

/**
 * The 'json_value(… , PASSING … AS … RETURNING … ERROR|NULL|DEFAULT on ERROR|EMPTY)' function
 */
jsonValueFunction
    : JSON_VALUE '(' expression ',' expression jsonPassingClause? jsonValueReturningClause? jsonValueOnErrorOrEmptyClause? jsonValueOnErrorOrEmptyClause? ')'
    ;

jsonValueReturningClause
    : RETURNING castTarget
    ;

jsonValueOnErrorOrEmptyClause
    : (ERROR | NULL | DEFAULT expression) ON (ERROR | EMPTY)
    ;

/**
 * The 'json_arrayagg( …, ABSENT ON NULL ORDER BY)' function
 */
jsonArrayAggFunction
    : JSON_ARRAYAGG '(' expressionOrPredicate jsonNullClause? orderByClause? ')' filterClause?;

/**
 * The 'json_objectagg( KEY? …, ABSENT ON NULL ORDER BY WITH|WITHOUT UNIQUE KEYS)' function
 */
jsonObjectAggFunction
    : JSON_OBJECTAGG '(' KEY? expressionOrPredicate (VALUE | ':') expressionOrPredicate jsonNullClause? jsonUniqueKeysClause? ')' filterClause?;

jsonPassingClause
    : PASSING aliasedExpressionOrPredicate (',' aliasedExpressionOrPredicate)*
    ;

jsonNullClause
    : (ABSENT | NULL) ON NULL;

jsonUniqueKeysClause
    : (WITH | WITHOUT) UNIQUE KEYS;

/**
 * The 'json_table(…, …, PASSING COLUMNS(…) ERROR|NULL ON ERROR)' function
 */
jsonTableFunction
    : JSON_TABLE '(' expression (',' expression)? jsonPassingClause? jsonTableColumnsClause jsonTableErrorClause? ')';

jsonTableErrorClause
    : (ERROR | NULL) ON ERROR;

jsonTableColumnsClause
    : COLUMNS '(' jsonTableColumns ')';

jsonTableColumns
    : jsonTableColumn (',' jsonTableColumn)*;

jsonTableColumn
    : NESTED PATH? STRING_LITERAL jsonTableColumnsClause                                                                            # JsonTableNestedColumn
    | identifier JSON jsonQueryWrapperClause? (PATH STRING_LITERAL)? jsonQueryOnErrorOrEmptyClause? jsonQueryOnErrorOrEmptyClause?  # JsonTableQueryColumn
    | identifier FOR ORDINALITY                                                                                                     # JsonTableOrdinalityColumn
    | identifier EXISTS (PATH STRING_LITERAL)? jsonExistsOnErrorClause?                                                             # JsonTableExistsColumn
    | identifier castTarget (PATH STRING_LITERAL)? jsonValueOnErrorOrEmptyClause? jsonValueOnErrorOrEmptyClause?                    # JsonTableValueColumn
    ;

xmlFunction
    : xmlElementFunction
    | xmlForestFunction
    | xmlPiFunction
    | xmlQueryFunction
    | xmlExistsFunction
    | xmlAggFunction
    ;

xmlElementFunction
    : XMLELEMENT '(' NAME identifier (',' xmlAttributesFunction)? (',' expressionOrPredicate)* ')'
    ;

xmlAttributesFunction
    : XMLATTRIBUTES '(' aliasedExpressionOrPredicate (',' aliasedExpressionOrPredicate)* ')'
    ;

xmlForestFunction
    : XMLFOREST '(' potentiallyAliasedExpressionOrPredicate (',' potentiallyAliasedExpressionOrPredicate)* ')'
    ;

xmlPiFunction
    : XMLPI '(' NAME identifier (',' expression)? ')';

xmlQueryFunction
    : XMLQUERY '(' expression PASSING expression ')';

xmlExistsFunction
    : XMLEXISTS '(' expression PASSING expression ')';

xmlAggFunction
    : XMLAGG '(' expression orderByClause? ')' filterClause? overClause?;

aliasedExpressionOrPredicate
    : expressionOrPredicate AS identifier
    ;

potentiallyAliasedExpressionOrPredicate
    : expressionOrPredicate (AS identifier)?
    ;

xmlTableFunction
    : XMLTABLE '(' expression PASSING expression xmlTableColumnsClause ')';

xmlTableColumnsClause
    : COLUMNS xmlTableColumn (',' xmlTableColumn)*;

xmlTableColumn
    : identifier XML (PATH STRING_LITERAL)? xmltableDefaultClause?          # XmlTableQueryColumn
    | identifier FOR ORDINALITY                                             # XmlTableOrdinalityColumn
    | identifier castTarget (PATH STRING_LITERAL)? xmltableDefaultClause?   # XmlTableValueColumn
    ;

xmltableDefaultClause
    : DEFAULT expression;

// Predicates
// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-conditional-expressions
predicate
    : '(' predicate ')'                     # GroupedPredicate
    | expression IS NOT? (NULL|EMPTY|TRUE|FALSE) # IsBooleanPredicate
    | expression IS NOT? DISTINCT FROM expression # IsDistinctFromPredicate
    | expression NOT? MEMBER OF? path       # MemberOfPredicate
    | inExpression                          # InPredicate
    | betweenExpression                     # BetweenPredicate
    | expression NOT? (CONTAINS|INCLUDES|INTERSECTS) expression   # ContainsPredicate
    | relationalExpression                  # RelationalPredicate
    | stringPatternMatching                 # LikePredicate
    | existsExpression                      # ExistsPredicate
    | NOT predicate                         # NotPredicate
    | predicate AND predicate               # AndPredicate
    | predicate OR predicate                # OrPredicate
    | expression                            # ExpressionPredicate
    ;

expressionOrPredicate
    : expression
    | predicate
    ;

collectionQuantifier
    : elementsValuesQuantifier
    | indicesKeysQuantifier
    ;

elementsValuesQuantifier
    : ELEMENTS
    | VALUES
    ;

elementValueQuantifier
    : ELEMENT
    | VALUE
    ;

indexKeyQuantifier
    : INDEX
    | KEY
    ;

indicesKeysQuantifier
    : INDICES
    | KEYS
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-relational-comparisons
// NOTE: The TIP shows that "!=" is also supported. Hibernate's source code shows that "^=" is another NOT_EQUALS option as well.
relationalExpression
    : expression op=('=' | '>' | '>=' | '<' | '<=' | '<>' | '!=' | '^=' ) expression
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-between-predicate
betweenExpression
    : expression NOT? BETWEEN expression AND expression
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-like-predicate
stringPatternMatching
    : expression NOT? (LIKE | ILIKE) expression (ESCAPE (STRING_LITERAL | JAVA_STRING_LITERAL |parameter))?
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-elements-indices
// TBD

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-in-predicate
inExpression
    : expression NOT? IN inList
    ;

inList
    : (ELEMENTS | INDICES) '(' simplePath ')'
    | '(' subquery ')'
    | parameter
    | '(' (expressionOrPredicate (',' expressionOrPredicate)*)? ')'
    ;

// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-exists-predicate
existsExpression
    : EXISTS (ELEMENTS | INDICES) '(' simplePath ')'
    | EXISTS expression
    ;

// Projection
// https://docs.jboss.org/hibernate/orm/6.1/userguide/html_single/Hibernate_User_Guide.html#hql-select-new
instantiationTarget
    : LIST
    | MAP
    | simplePath
    ;

instantiationArguments
    : instantiationArgument (',' instantiationArgument)*
    ;

instantiationArgument
    : (expressionOrPredicate | instantiation) variable?
    ;

// Low level parsing rules

parameterOrIntegerLiteral
    : parameter
    | INTEGER_LITERAL
    ;

parameterOrNumberLiteral
    : parameter
    | numericLiteral
    ;

/**
 * An identification variable (an entity alias)
 */
variable
    : AS identifier
    | nakedIdentifier
    ;

parameter
    : prefix=':' identifier
    | prefix='?' INTEGER_LITERAL?
    ;

entityName
    : identifier ('.' identifier)*
    ;

nakedIdentifier
    : IDENTIFIER
    | QUOTED_IDENTIFIER
    | f=(ABSENT
    | ALL
    | AND
    | ANY
    | ARRAY
    | AS
    | ASC
    | AVG
    | BETWEEN
    | BOTH
    | BREADTH
    | BY
    | CASE
    | CAST
    | COLLATE
    | COLUMN
    | COLUMNS
    | CONDITIONAL
    | CONFLICT
    | CONSTRAINT
    | CONTAINS
    | COUNT
    | CROSS
    | CUBE
    | CURRENT
    | CURRENT_DATE
    | CURRENT_INSTANT
    | CURRENT_TIME
    | CURRENT_TIMESTAMP
    | CYCLE
    | DATE
    | DATETIME
    | DAY
    | DEFAULT
    | DELETE
    | DEPTH
    | DESC
    | DISTINCT
    | DO
    | ELEMENT
    | ELEMENTS
    | ELSE
    | EMPTY
    | END
    | ENTRY
    | EPOCH
    | ERROR
    | ESCAPE
    | EVERY
    | EXCEPT
    | EXCLUDE
    | EXISTS
    | EXTRACT
    | FETCH
    | FILTER
    | FIRST
    | FK
    | FOLLOWING
    | FOR
    | FORMAT
    | FROM
    | FUNCTION
    | GROUP
    | GROUPS
    | HAVING
    | HOUR
    | ID
    | IGNORE
    | ILIKE
    | IN
    | INDEX
    | INCLUDES
    | INDICES
    | INSERT
    | INSTANT
    | INTERSECT
    | INTERSECTS
    | INTO
    | IS
    | JOIN
    | JSON
    | JSON_ARRAY
    | JSON_ARRAYAGG
    | JSON_EXISTS
    | JSON_OBJECT
    | JSON_OBJECTAGG
    | JSON_QUERY
    | JSON_TABLE
    | JSON_VALUE
    | KEY
    | KEYS
    | LAST
    | LATERAL
    | LEADING
    | LIKE
    | LIMIT
    | LIST
    | LISTAGG
    | LOCAL
    | LOCAL_DATE
    | LOCAL_DATETIME
    | LOCAL_TIME
    | MAP
    | MATERIALIZED
    | MAX
    | MAXELEMENT
    | MAXINDEX
    | MEMBER
    | MICROSECOND
    | MILLISECOND
    | MIN
    | MINELEMENT
    | MININDEX
    | MINUTE
    | MONTH
    | NAME
    | NANOSECOND
    | NATURALID
    | NEW
    | NESTED
    | NEXT
    | NO
    | NOT
    | NOTHING
    | NULLS
    | OBJECT
    | OF
    | OFFSET
    | OFFSET_DATETIME
    | ON
    | ONLY
    | OR
    | ORDER
    | ORDINALITY
    | OTHERS
    | OVER
    | OVERFLOW
    | OVERLAY
    | PAD
    | PATH
    | PARTITION
    | PASSING
    | PERCENT
    | PLACING
    | POSITION
    | PRECEDING
    | QUARTER
    | RANGE
    | RESPECT
    | RETURNING
    | RIGHT
    | ROLLUP
    | ROW
    | ROWS
    | SEARCH
    | SECOND
    | SELECT
    | SET
    | SIZE
    | SOME
    | SUBSTRING
    | SUM
    | THEN
    | TIES
    | TIME
    | TIMESTAMP
    | TIMEZONE_HOUR
    | TIMEZONE_MINUTE
    | TO
    | TRAILING
    | TREAT
    | TRIM
    | TRUNC
    | TRUNCATE
    | TYPE
    | UNBOUNDED
    | UNCONDITIONAL
    | UNION
    | UNIQUE
    | UPDATE
    | USING
    | VALUE
    | VALUES
    | VERSION
    | VERSIONED
    | WEEK
    | WHEN
    | WHERE
    | WITH
    | WITHIN
    | WITHOUT
    | WRAPPER
    | XML
    | XMLAGG
    | XMLATTRIBUTES
    | XMLELEMENT
    | XMLEXISTS
    | XMLFOREST
    | XMLPI
    | XMLQUERY
    | XMLTABLE
    | YEAR
    | ZONED)
    ;

identifier
    : nakedIdentifier
    | FULL
    | INNER
    | LEFT
    | OUTER
    | RIGHT
    ;

/*
    Lexer rules
 */


WS                          : [ \t\r\n] -> channel(HIDDEN);

// Build up case-insentive tokens

fragment A: 'a' | 'A';
fragment B: 'b' | 'B';
fragment C: 'c' | 'C';
fragment D: 'd' | 'D';
fragment E: 'e' | 'E';
fragment F: 'f' | 'F';
fragment G: 'g' | 'G';
fragment H: 'h' | 'H';
fragment I: 'i' | 'I';
fragment J: 'j' | 'J';
fragment K: 'k' | 'K';
fragment L: 'l' | 'L';
fragment M: 'm' | 'M';
fragment N: 'n' | 'N';
fragment O: 'o' | 'O';
fragment P: 'p' | 'P';
fragment Q: 'q' | 'Q';
fragment R: 'r' | 'R';
fragment S: 's' | 'S';
fragment T: 't' | 'T';
fragment U: 'u' | 'U';
fragment V: 'v' | 'V';
fragment W: 'w' | 'W';
fragment X: 'x' | 'X';
fragment Y: 'y' | 'Y';
fragment Z: 'z' | 'Z';

ASTERISK                    : '*';

// The following are reserved identifiers:

ID                          : I D;
VERSION                     : V E R S I O N;
VERSIONED                   : V E R S I O N E D;
NATURALID                   : N A T U R A L I D;
FK                          : F K;
ABSENT                      : A B S E N T;
ALL                         : A L L;
AND                         : A N D;
ANY                         : A N Y;
ARRAY                       : A R R A Y;
AS                          : A S;
ASC                         : A S C;
AVG                         : A V G;
BETWEEN                     : B E T W E E N;
BOTH                        : B O T H;
BREADTH                     : B R E A D T H;
BY                          : B Y;
CASE                        : C A S E;
CAST                        : C A S T;
COLLATE                     : C O L L A T E;
COLUMN                      : C O L U M N;
COLUMNS                     : C O L U M N S;
CONDITIONAL                 : C O N D I T I O N A L;
CONFLICT                    : C O N F L I C T;
CONSTRAINT                  : C O N S T R A I N T;
CONTAINS                    : C O N T A I N S;
COUNT                       : C O U N T;
CROSS                       : C R O S S;
CUBE                        : C U B E;
CURRENT                     : C U R R E N T;
CURRENT_DATE                : C U R R E N T '_' D A T E;
CURRENT_INSTANT             : C U R R E N T '_' I N S T A N T;
CURRENT_TIME                : C U R R E N T '_' T I M E;
CURRENT_TIMESTAMP           : C U R R E N T '_' T I M E S T A M P;
CYCLE                       : C Y C L E;
DATE                        : D A T E;
DATETIME                    : D A T E T I M E ;
DAY                         : D A Y;
DEFAULT                     : D E F A U L T;
DELETE                      : D E L E T E;
DEPTH                       : D E P T H;
DESC                        : D E S C;
DISTINCT                    : D I S T I N C T;
DO                          : D O;
ELEMENT                     : E L E M E N T;
ELEMENTS                    : E L E M E N T S;
ELSE                        : E L S E;
EMPTY                       : E M P T Y;
END                         : E N D;
ENTRY                       : E N T R Y;
EPOCH                       : E P O C H;
ERROR                       : E R R O R;
ESCAPE                      : E S C A P E;
EVERY                       : E V E R Y;
EXCEPT                      : E X C E P T;
EXCLUDE                     : E X C L U D E;
EXISTS                      : E X I S T S;
EXTRACT                     : E X T R A C T;
FETCH                       : F E T C H;
FILTER                      : F I L T E R;
FIRST                       : F I R S T;
FOLLOWING                   : F O L L O W I N G;
FOR                         : F O R;
FORMAT                      : F O R M A T;
FROM                        : F R O M;
FULL                        : F U L L;
FUNCTION                    : F U N C T I O N;
GROUP                       : G R O U P;
GROUPS                      : G R O U P S;
HAVING                      : H A V I N G;
HOUR                        : H O U R;
IGNORE                      : I G N O R E;
ILIKE                       : I L I K E;
IN                          : I N;
INCLUDES                    : I N C L U D E S;
INDEX                       : I N D E X;
INDICES                     : I N D I C E S;
INNER                       : I N N E R;
INSERT                      : I N S E R T;
INSTANT                     : I N S T A N T;
INTERSECT                   : I N T E R S E C T;
INTERSECTS                  : I N T E R S E C T S;
INTO                        : I N T O;
IS                          : I S;
JOIN                        : J O I N;
JSON                        : J S O N;
JSON_ARRAY                  : J S O N '_' A R R A Y;
JSON_ARRAYAGG               : J S O N '_' A R R A Y A G G;
JSON_EXISTS                 : J S O N '_' E X I S T S;
JSON_OBJECT                 : J S O N '_' O B J E C T;
JSON_OBJECTAGG              : J S O N '_' O B J E C T A G G;
JSON_QUERY                  : J S O N '_' Q U E R Y;
JSON_TABLE                  : J S O N '_' T A B L E;
JSON_VALUE                  : J S O N '_' V A L U E;
KEY                         : K E Y;
KEYS                        : K E Y S;
LAST                        : L A S T;
LATERAL                     : L A T E R A L;
LEADING                     : L E A D I N G;
LEFT                        : L E F T;
LIKE                        : L I K E;
LIMIT                       : L I M I T;
LIST                        : L I S T;
LISTAGG                     : L I S T A G G;
LOCAL                       : L O C A L;
LOCAL_DATE                  : L O C A L '_' D A T E ;
LOCAL_DATETIME              : L O C A L '_' D A T E T I M E;
LOCAL_TIME                  : L O C A L '_' T I M E;
MAP                         : M A P;
MATERIALIZED                : M A T E R I A L I Z E D;
MAX                         : M A X;
MAXELEMENT                  : M A X E L E M E N T;
MAXINDEX                    : M A X I N D E X;
MEMBER                      : M E M B E R;
MICROSECOND                 : M I C R O S E C O N D;
MILLISECOND                 : M I L L I S E C O N D;
MIN                         : M I N;
MINELEMENT                  : M I N E L E M E N T;
MININDEX                    : M I N I N D E X;
MINUTE                      : M I N U T E;
MONTH                       : M O N T H;
NAME                        : N A M E;
NANOSECOND                  : N A N O S E C O N D;
NEW                         : N E W;
NESTED                      : N E S T E D;
NEXT                        : N E X T;
NO                          : N O;
NOT                         : N O T;
NOTHING                     : N O T H I N G;
NULLS                       : N U L L S;
OBJECT                      : O B J E C T;
OF                          : O F;
OFFSET                      : O F F S E T;
OFFSET_DATETIME             : O F F S E T '_' D A T E T I M E;
ON                          : O N;
ONLY                        : O N L Y;
OR                          : O R;
ORDER                       : O R D E R;
ORDINALITY                  : O R D I N A L I T Y;
OTHERS                      : O T H E R S;
OUTER                       : O U T E R;
OVER                        : O V E R;
OVERFLOW                    : O V E R F L O W;
OVERLAY                     : O V E R L A Y;
PAD                         : P A D;
PATH                        : P A T H;
PARTITION                   : P A R T I T I O N;
PASSING                     : P A S S I N G;
PERCENT                     : P E R C E N T;
PLACING                     : P L A C I N G;
POSITION                    : P O S I T I O N;
PRECEDING                   : P R E C E D I N G;
QUARTER                     : Q U A R T E R;
RANGE                       : R A N G E;
RESPECT                     : R E S P E C T;
RETURNING                   : R E T U R N I N G;
RIGHT                       : R I G H T;
ROLLUP                      : R O L L U P;
ROW                         : R O W;
ROWS                        : R O W S;
SEARCH                      : S E A R C H;
SECOND                      : S E C O N D;
SELECT                      : S E L E C T;
SET                         : S E T;
SIZE                        : S I Z E;
SOME                        : S O M E;
SUBSTRING                   : S U B S T R I N G;
SUM                         : S U M;
THEN                        : T H E N;
TIES                        : T I E S;
TIME                        : T I M E;
TIMESTAMP                   : T I M E S T A M P;
TIMEZONE_HOUR               : T I M E Z O N E '_' H O U R;
TIMEZONE_MINUTE             : T I M E Z O N E '_' M I N U T E;
TO                          : T O;
TRAILING                    : T R A I L I N G;
TREAT                       : T R E A T;
TRIM                        : T R I M;
TRUNC                       : T R U N C;
TRUNCATE                    : T R U N C A T E;
TYPE                        : T Y P E;
UNBOUNDED                   : U N B O U N D E D;
UNCONDITIONAL               : U N C O N D I T I O N A L;
UNION                       : U N I O N;
UNIQUE                      : U N I Q U E;
UPDATE                      : U P D A T E;
USING                       : U S I N G;
VALUE                       : V A L U E;
VALUES                      : V A L U E S;
WEEK                        : W E E K;
WHEN                        : W H E N;
WHERE                       : W H E R E;
WITH                        : W I T H;
WITHIN                      : W I T H I N;
WITHOUT                     : W I T H O U T;
WRAPPER                     : W R A P P E R;
XML                         : X M L;
XMLAGG                      : X M L A G G;
XMLATTRIBUTES               : X M L A T T R I B U T E S;
XMLELEMENT                  : X M L E L E M E N T;
XMLEXISTS                   : X M L E X I S T S;
XMLFOREST                   : X M L F O R E S T;
XMLPI                       : X M L P I;
XMLQUERY                    : X M L Q U E R Y;
XMLTABLE                    : X M L T A B L E;
YEAR                        : Y E A R;
ZONED                       : Z O N E D;

NULL                        : N U L L;
TRUE                        : T R U E;
FALSE                       : F A L S E;

fragment
INTEGER_NUMBER
    : DIGIT+
    ;

fragment
FLOATING_POINT_NUMBER
    : DIGIT+ '.' DIGIT* EXPONENT?
    | '.' DIGIT+ EXPONENT?
    | DIGIT+ EXPONENT
    | DIGIT+
    ;

fragment
EXPONENT : [eE] [+-]? DIGIT+;

fragment HEX_DIGIT          : [0-9a-fA-F];

fragment SINGLE_QUOTE : '\'';
fragment DOUBLE_QUOTE : '"';

STRING_LITERAL : SINGLE_QUOTE ( SINGLE_QUOTE SINGLE_QUOTE | ~('\'') )* SINGLE_QUOTE;

JAVA_STRING_LITERAL
    : DOUBLE_QUOTE ( ESCAPE_SEQUENCE | ~('"') )* DOUBLE_QUOTE
    | [jJ] SINGLE_QUOTE ( ESCAPE_SEQUENCE | ~('\'') )* SINGLE_QUOTE
    | [jJ] DOUBLE_QUOTE ( ESCAPE_SEQUENCE | ~('\'') )* DOUBLE_QUOTE
    ;

INTEGER_LITERAL : INTEGER_NUMBER ('_' INTEGER_NUMBER)*;

LONG_LITERAL : INTEGER_NUMBER  ('_' INTEGER_NUMBER)* LONG_SUFFIX;

FLOAT_LITERAL : FLOATING_POINT_NUMBER FLOAT_SUFFIX;

DOUBLE_LITERAL : FLOATING_POINT_NUMBER DOUBLE_SUFFIX?;

BIG_INTEGER_LITERAL : INTEGER_NUMBER BIG_INTEGER_SUFFIX;

BIG_DECIMAL_LITERAL : FLOATING_POINT_NUMBER BIG_DECIMAL_SUFFIX;

HEX_LITERAL : '0' [xX] HEX_DIGIT+ LONG_SUFFIX?;

BINARY_LITERAL              : [xX] '\'' HEX_DIGIT+ '\''
                            | [xX] '"'  HEX_DIGIT+ '"'
                            ;

// ESCAPE start tokens
TIMESTAMP_ESCAPE_START : '{ts';
DATE_ESCAPE_START : '{d';
TIME_ESCAPE_START : '{t';

PLUS : '+';
MINUS : '-';



fragment
LETTER : [a-zA-Z\u0080-\ufffe_$];

fragment
DIGIT : [0-9];

fragment
LONG_SUFFIX : [lL];

fragment
FLOAT_SUFFIX : [fF];

fragment
DOUBLE_SUFFIX : [dD];

fragment
BIG_DECIMAL_SUFFIX : [bB] [dD];

fragment
BIG_INTEGER_SUFFIX : [bB] [iI];

// Identifiers
IDENTIFIER
    : LETTER (LETTER | DIGIT)*
    ;

fragment
BACKTICK : '`';

fragment BACKSLASH : '\\';

fragment
UNICODE_ESCAPE
    : 'u' HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT
    ;

fragment
ESCAPE_SEQUENCE
    : BACKSLASH [btnfr"']
    | BACKSLASH UNICODE_ESCAPE
    | BACKSLASH BACKSLASH
    ;

QUOTED_IDENTIFIER
    : BACKTICK ( ESCAPE_SEQUENCE | '\\' BACKTICK | ~([`]) )* BACKTICK
    ;
